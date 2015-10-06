
#' Erase
#' @description Function for the modification of the f.i. adjacency matrix resulting from merging communities OldCom and NewCom,
#' the row and column corresponding to OldCom are erased.
#' @param A Matrix which will be modified.
#' @param OldCom the community which the node have been.
#' @param NewCom the community which the node moved to.


Erase <- function(A,OldCom,NewCom)
{
  A[NewCom,] <- A[NewCom,]+ A[OldCom,]
  A[NewCom,NewCom] <- A[NewCom,NewCom] + A[OldCom,OldCom]
  A[,NewCom] <- A[NewCom,]
  return(A[-which(rownames(A)==OldCom),-which(colnames(A)==OldCom)])
}

#' NewNodesGroup
#' @description Updates table NodesGroups.
#' @param OldCom the community which the node have been.
#' @param NewCom the community which the node moved to.
#' @param NodesGroups table stores the number of the community to which a particular node is currently assigned.

NewNodesGroup <- function(OldCom,NewCom,NodesGroups)
{
  OldNumber <- NodesGroups[OldCom,"community"]
  NewNumber <- NodesGroups[NewCom,"community"]
  NodesGroups[which(NodesGroups$community==OldNumber),"community"] <- NewNumber

  return(NodesGroups)
}

#' Exp_matrix
#' @description Function for creating the matrix e^(t(B-I))k_j which is needed to computed stability.
#' @param A Adjacency matrix
#' @param p resolution parameter t

Exp_matrix <- function(A,p)
{

  v <- colSums(A)
  v[which(v==0)] <- min(v[v!=0])/1000
  B <- as.matrix(A) %*% diag(1/v)

  Adj <- as.matrix(expm::expm(p*(B-diag(1,nrow(B))),method = "Pade",order = 8))
  Adj <- Adj %*% diag(colSums(A))

}

#' Delta
#'  @description Computes value Delta(R_NL) for each neighbor at the same time and returned vector delta with these values.
#'
#' Delta(R_NL) evaluates the change of stability (R_NL) by removing Com1 from its community and
#' then by moving it into a neighbouring community. The node Com1 is then in cluster_resolution algotithm placed in the community for which
#' this gain is maximum, but only if this gain is positive.
#' @param A Adjacency matrix
#' @param Adj Matrix calxulated from pattern e^(t(B-I))k_j
#' @param Com1 node which is considered to change the community
#' @param Com2 neighbors of node Com2

Delta<- function(A,Adj,Com1,Com2)
{

  k_i_in <- Adj[Com1,Com2]
  m <- sum(A)/2
  if(length(Com2)==1){ S_tot <- sum(A[Com2,]) } else { S_tot <- rowSums(A[Com2,])}
  k_i <- sum(A[Com1,])

  return (k_i_in/(m) -(k_i *S_tot)/(2*(m^2)) )
}


#' cluster_resolution
#'
#' @description   cluster_resolution function has been created based on paper "Laplacian dynamics and Multiscale Modular Structure in Networks" R. Lambiotte et al.
#'                Algorithm finds communities using stability as an objective function to be optimised
#'                  in order to find the best partition  of network. The number of communities
#'                  typically decreases as time grows, from a partition of one-node communities which are as many as nodes when t = 0 to a
#'                  two-way partition as t → ∞.
#' @param graph An igraph network or a data frame of three columns: source, target, and weights.
#' @param t The time-scale parameter of the process which uncovers community structures at different resolutions.
#' @param directed Logical. TRUE if the network is directed. Ignored if graph is an igraph object.
#' @return Table with information about community which has been found for each node.
#' @examples
#' library(igraph)
#' g <- nexus.get("miserables")
#' cluster_resolution(g,directed=FALSE,t=1)



cluster_resolution <- function(graph, t = 1, directed=FALSE)
{

  if(igraph::is.igraph(graph)){
    g <- graph
  } else{
    g <- igraph::graph.data.frame(graph, directed=directed)
  }

  A <- igraph::get.adjacency(g, type="both",
                             attr=names(igraph::edge.attributes(g)), edges=FALSE, names=TRUE,
                             sparse=FALSE)

  CM <- as.matrix(A)

  #Initializing the table that informs about the community number to which a particular node is assigned
  NodesGroups <- data.frame(community=1:nrow(CM))
  rownames(NodesGroups) <- rownames(CM)

  # computing the matrix e^(t(B-I))k_j
  Adj <- Exp_matrix(CM,t)
  colnames(Adj) <- rownames(Adj)

  logic <- 1

  while (logic != 0 & nrow(CM) > 1 )
  {
    # names contains the names of communities which have not been "visited" yet in this iteration
    # a community is "visited" if it is merged with some other community or it was confirmed that no
    # increase in modularity  can be achieved by merging this community with any other
    names <- rownames(CM)

    # logic = 1 means that some increase of modularity has been achieved in the iteration
    logic <- 0

    while (length(names) > 0)
    {
      name1 <- names[1]
      max <- 0
      # analyze all the nodes in the neighborhood of name1
      neighborhood <- setdiff(rownames(CM)[which(CM[name1,]!=0)],name1)

      if(length(neighborhood) > 0)
      {
        delta <- Delta(CM,Adj,name1,neighborhood)
        if(length(neighborhood)==1){ names(delta) <- neighborhood}
        if(max(delta) > max){max <- max(delta); where<- names(delta)[which.max(delta)]; logic<-1}
      }


      # we have "visited" community name1 so we remove it from names
      names <- setdiff(names,name1)
      if(max >0)
      {
        # If there has been an increase in modularity
        # perform the merging that maximize this increase
        # modify the matrix CM and Adj
        # modify the NodesGroups table
        CM <- Erase(CM,name1,where)
        Adj <- Erase(Adj,name1,where)
        NodesGroups <- NewNodesGroup(name1,where,NodesGroups)

        #now we have also "visited" community "where" so we remove it from names
        names <- setdiff(names,where)
        if(length(CM) == 1) {CM <- as.matrix(CM)}
      }
    }
  }

  # modify the numbers denoting communities so that they are consecutive natural numbers starting from 1
  NodesGroups$community <- as.factor(NodesGroups$community)
  levels(NodesGroups$community) <- 1:length(levels(NodesGroups$community))
  NodesGroups$community <- as.numeric(NodesGroups$community)

  return (NodesGroups)
}




