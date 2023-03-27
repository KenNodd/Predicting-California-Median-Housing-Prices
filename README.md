# Predicting-California-Median-Housing-Prices
I was given data at the census tract level in California with metrics like latitude and longitude, median housing age, median income, and population, along with the "true" median housing value for the census tract. One important aspect of this dataset is that it capped out at a median housing value of $500,001; a reader with knowledge of the housing market in California will know that some areas in the state have median housing values in excess of this cap, and so, those outlier districts will not appear with their true-to-life values in the maps below. In order to predict median housing value given the data, I initialized a gradient boosting algorithm with a maximum number of 10,000 trees and an interaction depth of 6. I also performed two-fold cross validation on the model, which enabled me to find the optimal number of trees for my prediction based on out-of-sample performance. I found that the optimal model used 4,917 trees, with an out-of-sample RMSE of 46,856, which is a 23% percent average error when compared to the mean true median housing value of 206,868.

Notably, my original dataset did not include the GEOID of the relevant census tract for each row, which is the standard way to match data to census districts. Therefore, In order to both my original data and the predictions on a map of the Californian census tracts, I had to first match the latitude/longitude pairs I was given with census-tract GEOIDs. In so doing, I noticed an issue with the original data where the coordinates were rounded to the hundredth decimal place. This was not much of a problem for the large census tracts, but many census tracts in the dense urban areas of California are smaller in size than a hundredth of a coordinate. This rounding therefore lead to many rows having duplicated coordinates and being impossible to assign to a specific census tract, ultimately creating many holes in the map especially in downtown Los Angeles and San Francisco. While I could have fairly easily downloaded a more spacially accurate dataset from the census to match to those missing values, I decided instead to treat this as an exercise in working with imperfect data, which I believe is a valuable skill in a reality where imperfections are common in data, and the ability to simply download better data is rare. 

In order to solve the rounding problem I first segregated out the rows that could not be assigned with certaintly to a specific census tract and then used a fuzzy joining algorithm to match them to all census tracts within 0.5 miles of the given coordinates. I then took the median of those matched rows to color the census tract on the map. I have denoted census tracts colored this way on the maps for the true values and the predictions, and you can see that there do not appear to be very major aberations present.

Below I have attached images from the various maps I created for this project, however, due to the scale of the data (many census tracts are very small and tightly packed, and therefore illegible when viewing the entirety of California) I believe that the best way to view this data is through an interactive map that can be zoomed and panned. The code for these maps is provided along with my other work, however creating them is quite resource intensive, so I have also provided links below that will open each of the maps in your web browser. I highly encourage opening those files and panning around the maps yourself rather than relying solely on the images below.

Original Data:

(Interactive map: https://kennodd.github.io/Predicting-California-Median-Housing-Prices/True%20California%20Median%20Housing%20Values%20by%20Census%20Tract.html)

![fullTrue](https://user-images.githubusercontent.com/129005431/227804203-cac2cfb0-9e39-47ff-9fa8-1801aa871a48.png)

Los Angeles:

![laTrue](https://user-images.githubusercontent.com/129005431/227804226-c23e1afd-a255-4265-b17f-eec052a82691.png)

San Francisco:

![sfTrue](https://user-images.githubusercontent.com/129005431/227804214-584f25db-e8fe-4c56-80b3-0340780bec6b.png)

The yellow borders on these maps and also on the maps of my predictions below denote census tracts which were colored based on the fuzzy matching algorithm I described in the introduction.

Predicted Values:

(Interactive map: https://kennodd.github.io/Predicting-California-Median-Housing-Prices/California%20Median%20Housing%20Values%20by%20Census%20Tract%20(Predicted).html)

![fullPredictions](https://user-images.githubusercontent.com/129005431/227804239-8369bfb8-b3a3-4035-8eca-beebd0fdc263.png)

Los Angeles:

![laPredictions](https://user-images.githubusercontent.com/129005431/227804244-fd07e1cf-d83a-4550-80e9-e26f9f6b09ea.png)

San Francisco:

![sfPredictions](https://user-images.githubusercontent.com/129005431/227804246-59c73d0c-7e42-4bb2-b40f-581de6d1cafe.png)

Residual Errors:

(Interactive map: https://kennodd.github.io/Predicting-California-Median-Housing-Prices/Residual%20Error)

![fullResidual](https://user-images.githubusercontent.com/129005431/227804263-f12c6e02-e002-45aa-85a9-bcf0eaeef519.png)

Los Angeles:

![laResidual](https://user-images.githubusercontent.com/129005431/227804278-e0ed4e32-0a99-4785-874a-f7b2b0c675cc.png)

San Francisco:

![sfResidual](https://user-images.githubusercontent.com/129005431/227804299-98a135eb-7b16-4d20-9c8f-b0810b07b4fa.png)

I have also provided maps of the percentage error (residual divided by true median housing value), which I believe is a more useful assessment of accuracy—overvaluing a home by $20,000 in a market where the average home sells for $2,000,000 is much less severe than overvaluing by the same amount a home in a market where the average home value is $200,000, but the above graphs would color both districts the same.

Percent Error:

(Interactive map: https://kennodd.github.io/Predicting-California-Median-Housing-Prices/Percent%20Error.html)

![fullPercentError](https://user-images.githubusercontent.com/129005431/227804314-bfa81bb1-4915-4b5f-9397-cfcbece47b03.png)

Los Angeles:

![laPercentError](https://user-images.githubusercontent.com/129005431/227804325-cd9ae325-9f36-478d-a544-9921168d8845.png)

San Francisco:

![sfPercentError](https://user-images.githubusercontent.com/129005431/227804328-2e25045f-d742-4d3a-b432-7653f5c852c1.png)

