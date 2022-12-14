library(ISLR)
library(MASS)
library(caret)
library(glmnet)
library(tidyverse)
library(elasticnet)
library(factoextra)
library(purrr)
library(cluster)

setwd("C://Users/oscar/Desktop/DataMining/Submission/")
load("class_data.RData")   
load("cluster_data.RData")

set.seed(123)
xNewMatrix <- data.matrix(xnew)
ranIndex <- sample(1:400, 300)
trX <- x[ranIndex,]
tsX <- x[-ranIndex,]
trY <- y[ranIndex]
tsY <- y[-ranIndex]

xM <-data.matrix(trX)
cv.lasso <- cv.glmnet(xM, trY, alpha=1, family="binomial")
plot(cv.lasso)

cv.lasso$lambda.min

#### Extract coefficient 

coef(cv.lasso, cv.lasso$lambda.min)


#### Compute lasso model and tuning parameter
lasso.model <- glmnet(xM, trY, alpha = 1, family = "binomial",
                      lambda = cv.lasso$lambda.min)

xM_test <-data.matrix(tsX)
predProbs <- lasso.model %>% predict(newx = xM_test)
predLabel <- ifelse(predProbs > 0.5, 1, 0)

threds <- seq(0.3, 0.7, by=0.01)
accuracies <- rep(-1, length(threds))
for (i in 1:length(threds)) {
  curPredLabel <- ifelse(predProbs > threds[i], 1, 0)
  accuracies[i] <- mean(curPredLabel == tsY)
}
plot(x=threds, y=accuracies)


#### Elastic Net using 5 fold cross validation

yData <- data.frame(
  y = as.factor(y)
)
enetData <- cbind(x, yData)
enetMod <- train(y ~ .,
                 data=enetData,
                 method="glmnet",
                 trControl=trainControl(method="cv"),
                 preProcess=c("center", "scale"),
                 tuneGrid=expand.grid(
                   alpha=seq(0, 1, by =0.1),
                   lambda=seq(0.01, 0.09, by=0.01)
                 ))


enetMod



#### Extract v2 ,v147, v180, v215, v222, v305, v390, v401, 448
#### SVM with linear kernel

set.seed(4132023)
svc_dta2 <- enetData[, c("y", "V2","V147","V180", "V215","V222","V305","V390","V401","V448")]
svc <- train(
  y ~ .,
  data=svc_dta2,
  trControl=trainControl("cv", 5),
  method="svmLinear",
  tuneGrid = data.frame(C = c(1, 5, 10, 20, 100))
)

svc



#### SVM with polynomial kernel

svm <- train(
  y ~ .,
  data=svc_dta2,
  trControl=trainControl("cv", 5),
  method="svmPoly",
  tuneGrid=expand.grid(C=c(1, 10, 100, 200, 300, 500),
                       degree=2:4,
                       scale=1)
)

svm


#### SVM with radial kernel

svmR <- train(
  y ~ .,
  data=svc_dta2,
  method="svmRadial",
  trControl=trainControl("cv", 5),
  tuneGrid=expand.grid(
    C=c(20,30,40,50,60,70,80,90,100),
    sigma=seq(0.05, 0.25, by=0.01)
  )
)

svmR


#### Regression Tree with 9 predictors

set.seed(12)
caretTree <- train(
  y ~ .,
  data=svc_dta2,
  method="rpart",
  trControl = trainControl("cv", 5),
  tuneGrid = data.frame(cp=seq(0.001, 0.3, by=0.01))
)

caretTree
pred <- predict(caretTree, newdata=svc_dta2) 



#### Regression Tree with all 500 predictors

set.seed(12)
caretTree_1 <- train(
  y ~ .,
  data=enetData,
  method="rpart",
  trControl = trainControl("cv", 5),
  tuneGrid = data.frame(cp=seq(0.001, 0.3, by=0.01))
)

caretTree_1


#### Random Forest using all 500 predictors

set.seed(4202022)
rf_allPred <- train(
  y ~ .,
  data=enetData,
  method="rf",
  trControl=trainControl("cv", 5),
  tuneGrid = data.frame(mtry=seq(1, 499, by=20)),
  ntree=150
)

rf_allPred


#Random Forest using 9 predictors 

set.seed(12)
rf_9pred <- train(
  y ~ .,
  data=svc_dta2,
  method="rf",
  trControl=trainControl("cv", 5),
  tuneGrid = data.frame(mtry=seq(1, 8, by=1)),
  ntree=150
)

rf_9pred




predict(rf_9pred, newdata = xnew)

### test error getting from  9 predictor random forest cross validaton error
test_error <- 1 -  0.7100793 
ynew <- predict(rf_9pred, newdata = xnew)
save(ynew,test_error,file = "35.RData")




###clustering part
###doing pca first
res.pca <- prcomp(y, scale = TRUE)
fviz_eig(res.pca,)


result <- summary(res.pca)

options(max.print = 3000)
result$sdev
proportions <- as.vector(result$dev)
proportions <- result$sdev^2/sum(result$sdev^2) * 100

proportions_vec <- rep(-1, length(proportions))

for (i in 1:length(proportions)) {
  proportions_vec[i] <- proportions[[i]]
}

proportions_vec_cum <-  rep(-1, length(proportions))
for (i in 1:length(proportions)) {
  proportions_vec_cum[i] <- sum(proportions_vec[1:i])
}

plot(x=1:length(proportions), y=proportions_vec_cum, type="l")

##subset data using PCA
original_dta <- y
pca_100 <- res.pca$x[,1:100]
pca_250 <- res.pca$x[,1:250]
pca_400 <- res.pca$x[,1:400]


### using average silhouette of 100 pc dataset
set.seed(04172022)
wss_pca_100 <- function(k) {
  kmeans(pca_100, k, nstart = 25, iter.max = 25)$tot.withinss
}

avg_sil_pca_100 <- function(k) {
  km.res <- kmeans(pca_100, centers = k, nstart=25, iter.max = 25)
  ss <- silhouette(km.res$cluster, dist(pca_100))
  mean(ss[, 3])
}

kvalues <- 2:100
wssValues_pca_100 <- map_dbl(kvalues, wss_pca_100)
avg_sil_values_pca_100 <- map_dbl(kvalues, avg_sil_pca_100)
# bssValues <- map_dbl(kvalues, bss)
# tssValues <- map_dbl(kvalues, tss)
plot(x=kvalues, wssValues_pca_100,xlab="Number of K", ylab = "Total within cluster sum of sqaures") 
#plot(x=1:100, bssValues/tssValues)
plot(x=kvalues,avg_sil_values_pca_100, xlab="Number of K", ylab = "Average Silhouettes", type="l")

print("Selected cluster:")
which(avg_sil_values_pca_100 == max(avg_sil_values_pca_100))


### using average silhouette of 250 pc dataset
set.seed(04172022)
wss_pca_250 <- function(k) {
  kmeans(pca_250, k, nstart = 25, iter.max = 25)$tot.withinss
}

avg_sil_pca_250 <- function(k) {
  km.res <- kmeans(pca_250, centers = k, nstart=25, iter.max = 25)
  ss <- silhouette(km.res$cluster, dist(pca_250))
  mean(ss[, 3])
}

kvalues <- 2:100
wssValues_pca_250 <- map_dbl(kvalues, wss_pca_250)
avg_sil_values_pca_250 <- map_dbl(kvalues, avg_sil_pca_250)
# bssValues <- map_dbl(kvalues, bss)
# tssValues <- map_dbl(kvalues, tss)
plot(x=kvalues, wssValues_pca_250,xlab="Number of K", ylab = "Total within cluster sum of sqaures") 
#plot(x=2:100, bssValues/tssValues)
plot(x=kvalues,avg_sil_values_pca_250, xlab="Number of K", ylab = "Average Silhouettes", type="l")

#select k with average silhouette width
which( abs(avg_sil_values_pca_250 - 0.05238976  ) < 0.000001) + 1
which( abs(avg_sil_values_pca_250 - 0.05809190   ) < 0.000001) + 1
which( abs(avg_sil_values_pca_250 - 0.05588197   ) < 0.000001) + 1



### using average silhouette of 400 pc dataset
set.seed(04172022)
wss_pca_400 <- function(k) {
  kmeans(pca_400, k, nstart = 25, iter.max = 25)$tot.withinss
}

avg_sil_pca_400 <- function(k) {
  km.res <- kmeans(pca_400, centers = k, nstart=25, iter.max = 25)
  ss <- silhouette(km.res$cluster, dist(pca_400))
  mean(ss[, 3])
}

kvalues <- 2:100
wssValues_pca_400 <- map_dbl(kvalues, wss_pca_400)
avg_sil_values_pca_400 <- map_dbl(kvalues, avg_sil_pca_400)
# bssValues <- map_dbl(kvalues, bss)
# tssValues <- map_dbl(kvalues, tss)
plot(x=kvalues, wssValues_pca_400,xlab="Number of K", ylab = "Total within cluster sum of sqaures") 
#plot(x=2:100, bssValues/tssValues)
plot(x=kvalues,avg_sil_values_pca_400, xlab="Number of K", ylab = "Average Silhouettes", type="l")


which( abs(avg_sil_values_pca_400 - 0.05470467 ) < 0.000001) + 1
which( abs(avg_sil_values_pca_400 - 0.05126043  ) < 0.000001) +1 
which( abs(avg_sil_values_pca_400 - 0.05115952  ) < 0.000001) + 1

set.seed(04172022)
wss_original_dta <- function(k) {
  kmeans(original_dta, k, nstart = 25, iter.max = 25)$tot.withinss
}

avg_sil_original_dta <- function(k) {
  km.res <- kmeans(original_dta, centers = k, nstart=25, iter.max = 25)
  ss <- silhouette(km.res$cluster, dist(original_dta))
  mean(ss[, 3])
}

### using average silhouette of whole dataset
kvalues <- 2:100
wssValues_original_dta <- map_dbl(kvalues, wss_original_dta)
avg_sil_values_original_dta <- map_dbl(kvalues, avg_sil_original_dta)
# bssValues <- map_dbl(kvalues, bss)
# tssValues <- map_dbl(kvalues, tss)
plot(x=kvalues, wssValues_original_dta,xlab="Number of K", ylab = "Total within cluster sum of sqaures") 
#plot(x=2:100, bssValues/tssValues)
plot(x=kvalues,avg_sil_values_original_dta, xlab="Number of K", ylab = "Average Silhouettes", type="l")

###report result for 400 PC
print("Selected cluster:")
which(avg_sil_values_original_dta == max(avg_sil_values_original_dta)) + 1