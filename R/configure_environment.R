#' Configure working environment
#' @param path Directory where data structure will be built.
#' @return A YAML file with key parameters.
#' @details {Returns a YAML file containing key parameters guiding the
#' production of ecosystem observations from species observations. Most
#' parameters are defined internally based on a template included in the
#' package. However, some parameters can be modified by the user, namely:
#' \itemize{
#'   \item{\emph{gbif -} This is a list containing the
#'   username and password used to obtain data from GBIF}
#'   \item{\emph{resolution -} Spatial resolution (in degrees)
#'   for which to produce ecosystem observations.}
#'   \item{\emph{max_gps_error -} Maximum GPS uncertainty
#'   (or 'error', in meters) to help preemptively exclude
#'   species observations from further processing.}
#'   #'   \item{\emph{extent -} geographical extent (in Degrees) from which
#'   to derive ecosystem observation. This will influence the location of
#'   samples as they will be derived for unique pixels in an equidistant grid.}
#'   \item{\emph{years -} Range of years when to derive ecosystem observations}
#' }}
#'
#' @export

#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

configure_environment = function(
    path, gbif=list(user="username", pwd="password"),
    resolution=0.00027777778, max_gps_error=30,
    extent=c(-180,180,-90,90), years=c(2000,2020)) {

  ## Check input argument ----
  ##==========================================================================#

  # check working directory
  if (!exists(path)) stop("'path' not found")
  if (min(!exists(file.path(path, "data", "analyses", "tmp"))))
    stop("missing key directories; use build_environment()")

  # check numeric input parameters
  if (!is.numeric(resolution)) stop("'resolution' must be numeric")
  if (length(resolution) > 1) stop("'resolution' must a single element")
  if (!is.numeric(max_gps_error)) stop("'max_gps_error' must be numeric")
  if (length(max_gps_error) > 1) stop("'max_gps_error' must a single element")
  if (!is.numeric(extent)) stop("'extent' must be numeric")
  if (length(extent) < 4) stop("'extent' must a 4-element vector")
  if (!is.numeric(years)) stop("'years' must be numeric")
  if (length(years) < 4) stop("'years' must a 2-element vector")

  # check data access credentials
  if (!is.list(gbif)) stop("'gbif' must be a 3-element list")
  n = c("user","pwd")
  if (min(names(gbif) %in% n) == 0)
    stop(paste0("keywords missing from 'gbif': ",
                paste0(n[!n %in% names(gbif)], collapse=", ")))

  ## update parameters ----
  ##==========================================================================#

  # load template from package
  file_path = system.file("extdata", "config.yml", package="GlobES.validation")
  config = read_yaml(file_path)

  # update credentials used to obtain GBIF data
  config$gbif$user = gbif$user
  config$gbif$pwd = gbif$pwd

  # spatial configurations
  resolution = resolution # target sample resolution
  extent = extent # processing extent (min x, max x, min y, max y)
  max_error= max_gps_error # maximum GPS uncertainty of samples (in meters)

  # temporal configuration
  obs_years = years # target year range of data processing

  # save updated yaml file
  file_path = file.path(path, "config.yml")
  write_yaml(config, file_path)

}
