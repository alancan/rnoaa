#' Get ERDDAP griddap data.
#'
#' @export
#' @import digest
#' @importFrom reshape2 melt
#'
#' @param x Anything coercable to an object of class erddap_info. So the output of a call to
#' \code{erddap_info}, or a datasetid, which will internally be passed through \code{erddap_info}.
#' @param ... Dimension arguments.
#' @param fields Fields to return, a character vector.
#' @param stride (integer) How many values to get. 1 = get every value, 2 = get every other value,
#' etc. Default: 1 (i.e., get every value)
#' @param fmt (character) One of csv (default) or ncdf
#' @param store One of \code{disk} (default) or \code{memory}. You can pass options to \code{disk}
#' @param callopts Pass on curl options to \code{\link[httr]{GET}}
#'
#' @details Details:
#'
#' @section Dimensions and Variables:
#' ERDDAP grid dap data has this concept of dimenions vs. variables. So, dimensions are things
#' like time, latitude, longitude, and altitude. Whereas variables are the measured variables,
#' e.g., temperature, salinity, and air.
#'
#' You can't separately adjust values for dimensions for different variables. So, here's how it's
#' gonna work:
#'
#' Pass in lower and upper limits you want for each dimension as a vector (e.g., \code{c(1,2)}),
#' or leave to defaults (i.e., don't pass anything to a dimension). Then pick which variables
#' you want returned via the \code{fields} parameter. If you don't pass in options to the
#' \code{fields} parameter, you get all variables back.
#'
#' To get the dimensions and variables, along with other metadata for a dataset, run
#' \code{erddap_info}, and each will be shown, with their min and max values, and some
#' other metadata.
#'
#' @section Where does the data go?:
#' You can choose where data is stored. Be careful though. With griddap data, you can easily get a
#' single file of hundreds of MB's or GB's in size with a single request. Using \code{disk()}
#' caches files based on the URL of the request you perform, which is the combination of all
#' parameters passed in, so if you refine a query by certain fields, etc., you will cach a
#' different file.  If you choose \code{overwrite=TRUE} within the \code{disk()} function then
#' you'll force writing a new file to disk. When you use \code{memory()}, no files are cached,
#' data is stored in R's memory.
#'
#' @references \url{http://upwell.pfeg.noaa.gov/erddap/index.html}
#' @seealso \code{\link{erddap_table}} \code{\link{erddap_clear_cache}}
#' @author Scott Chamberlain <myrmecocystus@@gmail.com>
#' @examples \dontrun{
#' # single variable dataset
#' ## You can pass in the outpu of a call to erddap_info
#' (out <- erddap_info('noaa_esrl_027d_0fb5_5d38'))
#' (res <- erddap_grid(out,
#'  time = c('2012-01-01','2012-06-12'),
#'  latitude = c(21, 18),
#'  longitude = c(-80, -75)
#' ))
#' ## Or, pass in a dataset id
#' (res <- erddap_grid(x='noaa_esrl_027d_0fb5_5d38',
#'  time = c('2012-01-01','2012-06-12'),
#'  latitude = c(21, 18),
#'  longitude = c(-80, -75)
#' ))
#'
#' # multi-variable dataset
#' (out <- erddap_info('noaa_gfdl_5081_7d4a_7570'))
#' (res <- erddap_grid(out,
#'  time = c('2005-11-01','2006-01-01'),
#'  latitude = c(20, 21),
#'  longitude = c(10, 11)
#' ))
#' (res <- erddap_grid(out, time = c('2005-11-01','2006-01-01'), latitude = c(20, 21),
#'    longitude = c(10, 11), fields = 'uo'))
#' (res <- erddap_grid(out, time = c('2005-11-01','2006-01-01'), latitude = c(20, 21),
#'    longitude = c(10, 11), fields = 'uo', stride=c(1,2,1,2)))
#' (res <- erddap_grid(out, time = c('2005-11-01','2006-01-01'), latitude = c(20, 21),
#'    longitude = c(10, 11), fields = c('uo','so')))
#' (res <- erddap_grid(out, time = c('2005-09-01','2006-01-01'), latitude = c(20, 21),
#'    longitude = c(10, 11), fields = 'none'))
#'
#' # multi-variable dataset
#' ## this one also has a 0-360 longitude system, BLARGH!!!
#' (out <- erddap_info('noaa_gfdl_3c96_7879_a9d3'))
#' (res <- erddap_grid(out,
#'  time = c('2005-11-01','2006-01-01'),
#'  latitude = c(20, 22),
#'  longitude = c(-80, -75)
#' ))
#' (res <- erddap_grid(out,
#'  time = c('2005-11-01','2006-01-01'),
#'  latitude = c(20, 22),
#'  longitude = c(-80, -75),
#'  depth = c(5, 50)
#' ))
#'
#' # Write to memory (within R), or to disk
#' (out <- erddap_info('noaa_pfeg_e9ae_3356_22f8'))
#' ## disk, by default (to prevent bogging down system w/ large datasets)
#' ## you can also pass in path and overwrite options to disk()
#' (res <- erddap_grid(out,
#'  time = c('2012-06-01','2012-06-12'),
#'  latitude = c(20, 21),
#'  longitude = c(-80, -75),
#'  store = disk()
#' ))
#' ## the 2nd call is much faster as it's mostly just the time of reading in the table from disk
#' system.time( erddap_grid(out,
#'  time = c('2012-06-01','2012-06-12'),
#'  latitude = c(20, 21),
#'  longitude = c(-80, -75),
#'  store = disk()
#' ) )
#' system.time( erddap_grid(out,
#'  time = c('2012-06-01','2012-06-12'),
#'  latitude = c(20, 21),
#'  longitude = c(-80, -75),
#'  store = disk()
#' ) )
#'
#' ## memory
#' (res <- erddap_grid(out,
#'  time = c('2012-06-01','2012-06-12'),
#'  latitude = c(20, 21),
#'  longitude = c(-80, -75),
#'  store = memory()
#' ))
#' }

erddap_grid <- function(x, ..., fields = 'all', stride = 1, 
  fmt = "csv", store = disk(), callopts = list())
{
  x <- as.erddap_info(x)
  dimargs <- list(...)
  d <- attr(x, "datasetid")
  var <- field_handler(fields, x$variables$variable_name)
  dims <- dimvars(x)
  if(all(var == "none")){
    args <- paste0(sapply(dims, function(y) parse_args(x, y, stride, dimargs, wname = TRUE)), collapse = ",")
  } else {
    pargs <- sapply(dims, function(y) parse_args(x, y, stride, dimargs))
    args <- paste0(lapply(var, function(y) paste0(y, paste0(pargs, collapse = ""))), collapse = ",")
  }
  resp <- erd_up_GET(url = sprintf("%sgriddap/%s.%s", eurl(), d, fmt), dset = d, args, store, fmt, callopts)
  loc <- if(store$store == "disk") resp else "memory"
  structure(read_upwell(resp, fmt), class=c("erddap_grid","data.frame"), datasetid=d, path=loc)
}

#' @export
print.erddap_grid <- function(x, ..., n = 10){
  cat(sprintf("<NOAA ERDDAP griddap> %s", attr(x, "datasetid")), sep = "\n")
  cat(sprintf("   Path: [%s]", attr(x, "path")), sep = "\n")
  if(attr(x, "path") != "memory"){
    finfo <- file_info(attr(x, "path"))
    cat(sprintf("   Last updated: [%s]", finfo$mtime), sep = "\n")
    cat(sprintf("   File size:    [%s]", finfo$size), sep = "\n")
  }
  cat(sprintf("   Dimensions:   [%s X %s]\n", NROW(x), NCOL(x)), sep = "\n")
  trunc_mat_(x, n = n)
}

field_handler <- function(x, y){
  x <- match.arg(x, c(y, "none", "all"), TRUE)
  if(length(x) == 1 && x == "all"){
    y
  } else if(all(x %in% y) || x == "none") {
    x
  }
}

parse_args <- function(.info, dim, s, dimargs, wname=FALSE){
  tmp <- if(dim %in% names(dimargs)){
    dimargs[[dim]]
  } else {
    if(dim == "time"){
      times <- c(getvar(.info, "time_coverage_start"), getvar(.info, "time_coverage_end"))
      sprintf('[(%s):%s:(%s)]', times[1], s, times[2])
    } else {
      actrange <- foo(.info$alldata[[dim]], "actual_range")
      gsub("\\s+", "", strsplit(actrange, ",")[[1]])
    }
  }
  if(length(s) > 1){
    if(!length(s) == length(dimvars(.info))) stop("Your stride vector must equal length of dimension variables", call. = FALSE)
    names(s) <- dimvars(.info)
    if(!wname)
      sprintf('[(%s):%s:(%s)]', tmp[1], s[[dim]], tmp[2])
    else
      sprintf('%s[(%s):%s:(%s)]', dim, tmp[1], s[[dim]], tmp[2])
  } else {
    if(!wname)
      sprintf('[(%s):%s:(%s)]', tmp[1], s, tmp[2])
    else
      sprintf('%s[(%s):%s:(%s)]', dim, tmp[1], s, tmp[2])
  }
}

getvar <- function(x, y){
  x$alldata$NC_GLOBAL[ x$alldata$NC_GLOBAL$attribute_name == y, "value"]
}

getvars <- function(x){
  vars <- names(x$alldata)
  vars[ !vars %in% c("NC_GLOBAL","time", x$variables$variable_name) ]
}

getallvars <- function(x){
  vars <- names(x$alldata)
  vars[ !vars %in% "NC_GLOBAL" ]
}

dimvars <- function(x){
  vars <- names(x$alldata)
  vars[ !vars %in% c("NC_GLOBAL", x$variables$variable_name) ]
}

erd_up_GET <- function(url, dset, args, store, fmt, ...){
  if(store$store == "disk"){
    out <- suppressWarnings(cache_get(cache = TRUE, url = url, args = args, path = store$path))

    # fpath <- path.expand(file.path(store$path, paste0(dset, ".csv")))
    if( !is.null( out ) && !store$overwrite ){ 
      out 
    } else {
      dir.create(store$path, showWarnings = FALSE, recursive = TRUE)
      res <- GET(url, query=args, write_disk(write_path(store$path, url, args, fmt), store$overwrite), ...)
      out <- check_response_erddap(res, fmt)
      if(res$status_code != 200) unlink(res$request$writer[[1]])
      if(grepl("Error", out, ignore.case = TRUE)) NA else res$request$writer[[1]]
    }
  } else {
    res <- GET(url, query=args, ...)
    out <- check_response_erddap(res, fmt)
    if(grepl("Error", out, ignore.case = TRUE)) NA else res
  }
}

file_info <- function(x){
  tmp <- file.info(x)
  row.names(tmp) <- NULL
  tmp2 <- tmp[,c('mtime','size')]
  tmp2$size <- if(tmp2$size < 10000) paste0(round(tmp2$size/1000L, 2), " KB") else paste0(round(tmp2$size/1000000L, 2), " MB")
  tmp2
}

# file = "~/.rnoaa/erddap/e93051f9010dbbd568fca953a71acae7.nc"
get_ncdf <- function(file){
  nc <- open.ncdf(file)
  lat <- get.var.ncdf(nc, "latitude")
  long <- get.var.ncdf(nc, "longitude")
  time <- get.var.ncdf(nc, "time")
  vars <- names(nc$var)
  outvars <- list()
  for(i in seq_along(vars)){
    outvars[[ vars[i] ]] <- melt(get.var.ncdf(nc, vars[i]))[,"value"]
  }
  df <- do.call("cbind.data.frame", outvars)
  rows <- length(outvars[[1]])
  meta <- data.frame(time=rep(time, each=rows/length(time)),
                   lat=rep(lat, each=rows/length(lat)),
                   long=rep(long, each=rows/length(long)),
                   stringsAsFactors = FALSE)
  alldf <- cbind(meta, df)
  close.ncdf(nc)
  alldf
}
