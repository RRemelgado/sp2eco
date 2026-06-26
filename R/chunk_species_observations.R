#-----------------------------------------------------------------------------#
#' Chunk data obtained from GBIF.
#' @param path Path to CSV file containing GBIF data to be processed.
#' @return A list of CSV files with a maximum of 100,000 lines of data each.
#' @importFrom countrycode countrycode
#' @importFrom readr write_csv
#' @details Chunks data obtained with \code{\link[aquire_gbif_data]).
#' @export
#-----------------------------------------------------------------------------#

chunk_gbif_data = function(path) {

  ## Check input parameters ----
  ##==========================================================================#

  if (!file.exists(path)) stop("'path' does not lead to a file")

  # create directory to host chunked data
  tmp_path = file.path(dirname(path), "gbif")
  if (!dir.exists(tmp_path)) dir.create(tmp_path)

  ## process species observations ----
  ##========================================================================#

  # define columns to be used
  target_columns = c("taxonKey", "species", "decimalLongitude",
                     "decimalLatitude", "year", "countryCode",
                     "coordinateUncertaintyInMeters",
                     "issue", "basisOfRecord")

  # read header
  con = file(path, "r")
  header = strsplit(readLines(con, n=1), "\t")[[1]]
  ind = match(target_columns, header) #  find matching columns

  ### process data in chunks if required ----
  ####========================================================================#

  id = 0 # unique identifier for each chunk
  control = 0 # variable checking if more chunks can be processed

  while (control == 0) {

    id = id + 1
    print(id)

    # extract data from file
    lines = readLines(con, n=100000)

    # check if file exists; if not, continue
    oname = file.path(tmp_path, paste0(as.character(id), ".csv"))

    if (file.exists(oname)) next
    if (length(lines) == 0) break

    # Split the lines into columns
    data_chunk <- as.data.frame(do.call(rbind, lapply(lines, function(line) {
      strsplit(line, "\t")[[1]][ind]})), stringsAsFactors=F)
    colnames(data_chunk) = config$gbif$col

    # update format of columns
    data_chunk$countryCode = countrycode(data_chunk$countryCode, "iso2c", "iso3c")
    data_chunk$coordinateUncertaintyInMeters = as.numeric(data_chunk$coordinateUncertaintyInMeters)
    data_chunk$coordinateUncertaintyInMeters[is.na(data_chunk$coordinateUncertaintyInMeters)] = 0
    data_chunk$year = as.numeric(data_chunk$year)
    data_chunk$issue[is.na(data_chunk$issue)] = ""

    # remove incomplete entries
    data_chunk = data_chunk[complete.cases(data_chunk),]

    # save data chunk
    if (nrow(data_chunk) > 0) write_csv(data_chunk, oname)

    invisible(gc())

  }

  # Close the file connection
  close(con)

}
