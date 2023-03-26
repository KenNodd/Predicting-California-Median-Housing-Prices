library(tidyverse)
library(ggmap)
library(tidycensus)
library(MazamaLocationUtils)
library(tigris)
library(fuzzyjoin)
library(sf)
library(data.table)

#these libraries are called in their own code sections:
# library(plotly)
# library(modelr)
# library(gbm)
# library(rpart)
# library(rpart.plot)
# library(rsample) 
# library(randomForest)
########################Introductory Steps############################

#load data
houseData <- read.csv("CAhousing.csv")

block <- read.csv("CAHousesGEOID.csv")

#The "block" dataset matches lat/lon coordinates with census tract GEOID's
#if you would like to see how it was created, the code is below, but takes 
#a while to run

# blocks <- apply(houseData, 1, 
#                 function(col) location_getCensusBlock(col['longitude'], col['latitude'], 2020, TRUE)[[3]])
# 
# lonLat <- houseData %>%
#   select(longitude, latitude)
# 
# block <- lonLat%>%
#   mutate("number" = NA)
# i <- 1
# for (i in 22170:20640) {
#   temp <- location_getCensusBlock(
#     longitude = block$longitude[i],
#     latitude = block$latitude[i],
#     censusYear = 2020,
#     verbose = FALSE
#   )[[3]]
#   if(length(temp) != 0){
#     block$number[i] <- temp
#   } else {
#     block$number[i] <- NA
#   }
#   i = i+1
#   if(i%%100 == 0){
#     variable2 <- paste0("Progress:",(i/20640)*100,"%")
#     print(variable2)
#   }
# }
#rm(temp)
#rm(variable2)
##############################################################

#Fix excel created problems
options(scipen = 999)
block <- block %>%
  mutate("number" = as.character(number)) %>%
  select(longitude, latitude, number)

#attach GEOID numbers to houseData 
#(they are in the same order due to how the original files were created)
houseData <- houseData %>%
  mutate("GEOID" = block$number, "latLon" = paste(longitude, latitude))

#three coordinate pairs lie outside of California:
#-114.49 33.97
#-119.94 38.96
#-117.04 32.54

#remove those rows:
houseData <- houseData %>%
  filter(!(latLon == "-114.49 33.97" | latLon == "-119.94 38.96" | latLon == "-117.04 32.54"))

###----------------------------------------Prediction---------------------------------------------###
library(modelr)
library(gbm)
library(rpart)
library(rpart.plot)
library(rsample) 
library(randomForest)

#here I fit a boost with 10,000 trees; this can take awhile, I ended up using 4,917 trees for the predictions so
#you can probably use a smaller maximum for the fitting if you like
boost = gbm(medianHouseValue~longitude + latitude + housingMedianAge + totalRooms +
              totalBedrooms + population + households + medianIncome, data=houseData, interaction.depth=6, n.trees=10000, shrinkage=.05, cv.folds = 2)
#4917 trees optimal, out-of-sample RMSE using 2 folds = 46,856.73

#add predictions to data
houseData = houseData %>%
  mutate(value_pred = predict(boost, n.trees = 4917))

rm(boost)

###----------------------------Merging Scott's data with Shape data-------------------------------###

#load in tract shape data for mapping, this requires an internet connection
tigrisTracts <- tracts(state = "CA", year = 2021)

#remove tracts with no land area (coaslines etc)
tigrisTracts <- tigrisTracts %>%
  filter(ALAND != 0) %>%
  mutate("GEOID" = substr(GEOID, 2, 11))

#change lat/lon to numerical
tigrisTracts <- tigrisTracts %>%
  mutate("INTPTLAT" = str_sub(string = INTPTLAT,start =  2,end = -1)) %>%
  mutate("INTPTLAT" = as.numeric(INTPTLAT), "INTPTLON" = as.numeric(INTPTLON))

#merge shape data with explanatory data by GEOID
houseDataTracts <- houseData %>%
  mutate(GEOID = substr(GEOID, 1, 10))

  #segregating duplicated GEOIDs from Scott's data
houseDataNoD <- houseDataTracts %>%
  distinct(GEOID, .keep_all = TRUE)
houseDataD <- houseDataTracts %>%
  group_by(GEOID) %>% filter(n() > 1) %>%
  ungroup() %>%
  select(!(GEOID))

  #merging the non-duplicated values
tMergeTracts <- tigrisTracts %>%
  select("GEOID","INTPTLAT", "INTPTLON", "geometry")
tMergeTracts <- merge(tMergeTracts, houseDataNoD, all = TRUE, by = "GEOID")
  #removing unmached rows(no prediction)
unmatched <- tMergeTracts %>%
  filter(is.na(value_pred))%>%
  mutate("longitude" = INTPTLON, "latitude" = INTPTLAT) %>%
  select(GEOID, longitude, latitude, geometry) %>%
  mutate("fuzzy" = 1)

  #transforming into a non-sf object to enable merge
geom <- st_as_text(st_sfc(unmatched$geometry))
unmatched <- unmatched %>% st_drop_geometry() %>% cbind(geom)

  #merging unmatched with duplicated values based on closest lat/lon
joined <- fuzzyjoin::geo_full_join(unmatched, houseDataD, by = c("longitude", "latitude"), max_dist = 0.5)
  #remove rows that didn't match to a geometry
joined <- joined %>%
  filter(!(is.na(geom)))
  #clean
joined <- joined %>%
  select(GEOID, "longitude" = longitude.x,"latitude" = latitude.x, housingMedianAge:value_pred, geom, fuzzy)
  #aggregate duplicated GEOIDs by the median of other variables
joined <- aggregate(cbind(housingMedianAge, totalRooms, totalBedrooms, population,
                          households, medianHouseValue, medianIncome, value_pred) ~ 
                    GEOID + geom + fuzzy, data = joined, FUN = median)

  #return df to sf object
joined <- joined %>%
  mutate("geometry" = geom) %>%
  select(!(geom))
joined <- st_as_sf(joined, wkt = "geometry", crs = "NAD83")


#extract rows with missing values
missingEstimate <- tMergeTracts %>%
  filter(is.na(value_pred))
  #removing those rows
tMergeTractsComp <- tMergeTracts %>%
  filter(!(is.na(value_pred)))
  #counting dups
sum(table(tMergeTractsComp$GEOID)-1)
    #13,800; plenty to fill 2,292 missing estimates

#attach rows created by fuzzy merge to complete dataset
joined <- joined %>%
  mutate("INTPTLAT" = NA, "INTPTLON" = NA, "longitude" = NA, "latitude" = NA, "latLon" = NA)
tMergeTractsComp <- tMergeTractsComp %>%
  mutate("fuzzy" = 0) %>%
  rbind(joined)

#create error measurements
tMergeTractsComp <- tMergeTractsComp %>%
  mutate("resid" = abs(value_pred - medianHouseValue))%>%
  mutate("percentErr" = resid/medianHouseValue)


rm(houseDataTracts)
rm(missingEstimate)
rm(houseDataNoD)
rm(unmatched)
rm(tMergeTracts)
rm(joined)
rm(houseDataD)

###---------------------------creating graphics----------------------------###
library(plotly)
#introductory to make the dataframe work with plotly
tMergeTractsComp <- tMergeTractsComp %>%
  mutate(fuzzy = ifelse(fuzzy == 1, "1", NA))
tMergeTractsComp1 <- tMergeTractsComp[!st_is_empty(tMergeTractsComp),,drop=FALSE]

dk_map <- sf::st_cast(tMergeTractsComp1, "MULTIPOLYGON")

options(scipen=10000)
#all of the below tables are quite resource intensive to build. For that reason, I have included HTML files
#and PNGs in the submission
#Predicted housing value
ggplotly(
  ggplot(dk_map)+
    geom_sf(mapping = aes(fill = value_pred, color = fuzzy))+
    scale_color_manual(values = c("yellow"), na.translate = FALSE) +
    guides(color = FALSE, size = FALSE)+
    labs(fill = "Predicted Median Housing Value", title = "California Median Housing Values by Census Tract (Predicted)")
)

#true housing value
ggplotly(
  ggplot(dk_map)+
    geom_sf(mapping = aes(fill = medianHouseValue, color = fuzzy))+
    scale_color_manual(values = c("yellow"), na.translate = FALSE) +
    guides(color = FALSE, size = FALSE)+
    labs(fill = "True Median Housing Value", title = "California Median Housing Values by Census Tract")
)

#residual
ggplotly(
  ggplot(dk_map)+
    geom_sf(aes(fill = resid), color = NA)+
    scico::scale_fill_scico(palette = "lajolla") +
    labs(fill = "Residual", title = "Residual Error from Predicted and True Median Housing Value")
)

#Percentage error
ggplotly(
  ggplot(dk_map)+
    geom_sf(aes(fill = 100*percentErr), color = NA)+
    scico::scale_fill_scico(palette = "lajolla") +
    labs(fill = "Percent Error", title = "Error Margin Between Predicted and True Median Housing Value")
)

