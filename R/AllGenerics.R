#' @rdname STRProfiles-accessors
#' @export
setGeneric("alleles", function(x, ...) standardGeneric("alleles"))

#' @rdname STRProfiles-accessors
#' @export
setGeneric("alleles<-", function(x, ..., value) standardGeneric("alleles<-"))

#' @rdname STRProfiles-accessors
#' @export
setGeneric("markers", function(x, ...) standardGeneric("markers"))

#' @rdname STRProfiles-accessors
#' @export
setGeneric("markerData", function(x, ...) standardGeneric("markerData"))

#' @rdname STRProfiles-accessors
#' @export
setGeneric("markerData<-", function(x, ..., value) standardGeneric("markerData<-"))

#' @rdname STRProfiles-accessors
#' @export
setGeneric("sampleData", function(x, ...) standardGeneric("sampleData"))

#' @rdname STRProfiles-accessors
#' @export
setGeneric("sampleData<-", function(x, ..., value) standardGeneric("sampleData<-"))

#' @rdname STRProfiles-accessors
#' @export
setGeneric("provenance", function(x, ...) standardGeneric("provenance"))

#' @rdname STRComparison-accessors
#' @export
setGeneric("scores", function(x, ...) standardGeneric("scores"))

#' @rdname STRComparison-accessors
#' @export
setGeneric("params", function(x, ...) standardGeneric("params"))

#' @rdname STRComparison-accessors
#' @export
setGeneric("queryProfiles", function(x, ...) standardGeneric("queryProfiles"))

#' @rdname STRComparison-accessors
#' @export
setGeneric("referenceProfiles", function(x, ...) standardGeneric("referenceProfiles"))
