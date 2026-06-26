#-----------------------------------------------------------------------------#
#' Obtain species observation data from GBIF.
#' @param path Path to parent project directory.
#' @return A set of clean data chunks provided in a CSV format.
#' @importFrom yaml read_yaml
#' @importFrom countrycode countrycode
#' @importFrom CoordinateCleaner clean_coordinates
#' @importFrom GlobES.validation latitude_radius
#' @importFrom readr read_csv write_csv
#' @importFrom GlobES.validation  latitude_radius
#' @details {Cleans and standardize GBIF data chunked with
#' \code{\link[chunk_gbif]) accounting for various geospatial
#' issues (e.g., missing coordinates, likely wrong country
#' assignments, hosting institution coordinates).}
#' @export
#-----------------------------------------------------------------------------#

clean_gbif = function(path) {

  ## Check input parameters ----
  ##==========================================================================#

  if (!dir.exists(path)) stop("'path' is not a valid directory")

  input_path = file.path(path, "tmp", "gbif")
  if (!exists(input_path)) stop("missing key directories; use build_environment()")
  input_files = list.files(input_path, ".csv", full.names=T)
  if (length(input_files) == 0) stop('"no files to process')

  # create directory to host processed data
  output_path = file.path(path, "clean_observations")
  if (!dir.exists(output_path)) dir.create(output_path)

  ## clean species observations ----
  ##==========================================================================#

  for (input in input_files) {

    # read chunk of pre-sorted data
    data_chunk = read_csv(iname, col_types=cols(.default="c"))

    ### determine spatial precision of each species observation ----
    ####=====================================================================#

    # number of decimal places in longitude
    tmp = do.call(rbind, strsplit(data_chunk$decimalLongitude, "[.]"))[,2]
    lon_p = sapply(tmp, function(l)
      (nchar(l)+1)-rle(rev(strsplit(l, "")[[1]]))$length[1])
    lon_p[names(lon_p) == "0"] = 0 # lowest precision (one decimal place of 0)

    # number of decimal places in latitude
    tmp = do.call(rbind, strsplit(data_chunk$decimalLatitude, "[.]"))[,2]
    lat_p = sapply(tmp, function(l)
      (nchar(l)+1)-rle(rev(strsplit(l, "")[[1]]))$length[1])
    lat_p[names(lat_p) == "0"] = 0 # lowest precision (one decimal place of 0)

    # estimate lowest precision at the target latitude
    precision = 111000 * latitude_radius(
      as.numeric(data_chunk$decimalLatitude)) / 6378.137

    # estimate precision of coordinates
    lon_p = precision/(10^lon_p)
    lat_p = precision/(10^lat_p)

    # update precision column
    data_chunk$coordinatePrecision = apply(cbind(lon_p,lat_p), 1, mean)
    data_chunk$decimalLongitude = as.numeric(data_chunk$decimalLongitude)
    data_chunk$decimalLatitude = as.numeric(data_chunk$decimalLatitude)

    #### clean observations
    ####=====================================================================#

    # flag data entries for geospatial issues
    flags = clean_coordinates(x=data_chunk,
                              lon="decimalLongitude",
                              lat="decimalLatitude",
                              countries="countryCode",
                              species="species")

    # remove data entries flagged for geospatial issues
    data_chunk = data_chunk[flags$.summary,]

    # save clean dataset
    write_csv(data_chunk, paste0("cleanObs_gbif_", basename(input)))

  }

}
