#' @title IBCF: Item Based Collaborative Filterign
#' @description Item Based Collaborative Filterign for multi-trait and multi-environment data.
#' @param DataSet \code{data.frame} Sets of data...
#' @param CrossValidation \code{list} List with the partitions
#'
#' @return
#' @export
#'
#' @examples
#'
IBCF <- function(DataSet, CrossValidation = NULL) {

  if (!is.data.frame(DataSet)) {
    stop('DataSet requieres be a data.frame object with')
  }
  if (is.null(CrossValidation)) {
    stop('Cross-Validation was not provided. Use the functions provided for this.')
  }

  #####Matrix for saving the observed and predicted values for each partion###
  Data.Obs_Pred <- data.frame(matrix(NA, nrow = nrow(DataSet), ncol = (2 * ncol(DataSet) - 2)))
  Data.Obs_Pred[, 1:(ncol(DataSet) - 1)] <- DataSet[, -c(1)]

  ##############Creating the partions of the cross-validation############
  # CrossValidation <- CV.RandomPart(NLine = nrow(DataSet), NEnv = NEnv, NTraits = NTraits, NPartitions = NPartitions, PTesting = PTesting)

  nIL <- ncol(DataSet) - 1

  ##########Saving the averages of Pearson corr and MSEP###########
  post_cor <- matrix(0, ncol = 1, nrow = nIL)
  post_cor_2 <- matrix(0, ncol = 1, nrow = nIL)
  post_MSEP <- matrix(0, ncol = 1, nrow = nIL)
  post_MSEP_2 <- matrix(0, ncol = 1, nrow = nIL)
  nSums <- 0

  NPartitions <- length(CrossValidation)
  Ave_predictions <- matrix(NA, ncol = 5, nrow = nIL)
  for (j in 1:NPartitions) {
    Part <- CrossValidation[[j]]

    pos.NA <- which(Part == 2, arr.ind = T)

    if (length(pos.NA) == 0){
      stop('An error ocurred with the CrossValidation data')
    }
    pos.NA[, 2] <- c(pos.NA[, 2]) + 1

    Data.trn <- DataSet

    Data.trn[pos.NA] <- NA

    rows.Na <- which(apply(Data.trn, 1, function(x) any(is.na(x))) == TRUE)

    Means_trn <- apply(Data.trn[, -c(1)], 2, mean, na.rm = T)
    SDs_trn <- apply(Data.trn[, -c(1)], 2, sd, na.rm = T)

    Mean_and_SD <- data.frame(cbind(Means_trn, SDs_trn))

    Scaled_Col <- scale(Data.trn[, -c(1)])

    Means_trn_Row <- apply(Scaled_Col, 1, mean, na.rm = T)
    SDs_trn_Row <- apply(Scaled_Col, 1, sd, na.rm = T)

    Scaled_Row <- t(scale(t(Scaled_Col)))

    Data.trn_scaled <- data.frame(cbind(Data.trn[, c(1)], Scaled_Row))

    Hybrids.New <- Data.trn_scaled
    Hybrids.New[, 2:ncol(Data.trn_scaled)] <- NA

    ratings <- Data.trn_scaled

    x <- ratings[, 2:(ncol(ratings))]

    x[is.na(x)] <- 0

    item_sim <- lsa::cosine(as.matrix((x)))

    ##############Positions with no missing values########################
    pos.used <- c(1:nrow(ratings))
    pos.complete <- pos.used[-rows.Na]
    pos.w.Na <- rows.Na

    Hyb.pred <- as.data.frame(Data.trn_scaled)
    pos.lim <- length(pos.w.Na)

    for (i in 1:pos.lim) {
      pos <- pos.w.Na[i]
      Hyb.pred[pos, c(2:ncol(Hyb.pred))] <- c(rec_itm_for_geno(pos, item_sim, ratings)[2:ncol(Hyb.pred)])
    }

    All.Pred <- data.matrix(Hyb.pred[,-1])

    All.Pred_O_Row <- t(sapply(1:nrow(All.Pred), function(i) (All.Pred[i,]*SDs_trn_Row[i] + Means_trn_Row[i])) )

    All.Pred_O <- sapply(1:ncol(All.Pred_O_Row), function(i) (All.Pred_O_Row[,i]*SDs_trn[i] + Means_trn[i]))
    colnames(All.Pred_O) <- colnames(Data.trn_scaled[,-c(1)])

    All.Pred_O_tst <- All.Pred_O[rows.Na,]

    Data.Obs_Pred[rows.Na, (ncol(All.Pred_O) + 1):(2 * ncol(All.Pred_O))] <- All.Pred_O[rows.Na,]

    DataSet_tst <- DataSet[rows.Na, -c(1)]

    Y_all_tst <- cbind(DataSet_tst, All.Pred_O_tst)

    Cor_all_tst <- cor(Y_all_tst[,1:nIL], Y_all_tst[,(nIL + 1):(2*nIL)])

    Dif_Obs_pred <- Y_all_tst[,1:nIL] - Y_all_tst[,(nIL + 1):(2*nIL)]

    Dif_Obs_pred2 <- Dif_Obs_pred^2

    MSEP <- apply(Dif_Obs_pred2, 2, mean)
    Cor_vec <- diag(Cor_all_tst)
    MSEP_vec <- MSEP

    nSums <- nSums + 1

    k <- (nSums - 1)/(nSums)
    post_cor <- post_cor*k + Cor_vec/nSums
    post_cor_2 <- post_cor_2*k + (Cor_vec^2)/nSums

    post_MSEP <- post_MSEP*k + MSEP_vec/nSums
    post_MSEP_2 <- post_MSEP_2*k + (MSEP_vec^2)/nSums
  }

  SD_Cor <- sqrt(post_cor_2 - (post_cor^2))
  SD_MSEP <- sqrt(post_MSEP_2 - (post_MSEP^2))

  Ave_predictions[,2] <- post_cor
  Ave_predictions[,3] <- SD_Cor/sqrt(NPartitions)
  Ave_predictions[,4] <- post_MSEP
  Ave_predictions[,5] <- SD_MSEP/sqrt(NPartitions)

  Ave_predictions <- data.frame(Ave_predictions)
  colnames(Ave_predictions) <- c('Env_Trait', 'Pearson', 'Cor_SE', 'MSEP', 'MSEP_SE')

  Ave_predictions$Env_Trait <- colnames(DataSet[,-c(1)])

  out <- list(NPartitions = NPartitions,
              Ave_predictions = Ave_predictions)
  class(out) <- 'IBCF'
  return(out)
}