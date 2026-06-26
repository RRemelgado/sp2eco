#' Location filter
#' @param x A character vector of x coordinates of species observations.
#' @param y A character vector of y coordinates of species observations.
#' @param e numeric vector with precision of each coordinate pairs formed between \emph{x} and \emph{y} (in meters).
#' @param species character vector with names of observed species.
#' @param iso2c character vector with ISO-2 country codes for each observations.
#' @param resolution target spatial resolution (in degrees)
#' @param g_ranges A \emph{SpatRaster} object.
#' @param e_ranges A list with 2-element vectors that represent elevation ranges of species occurrences.
#' @param elevation \emph{SpatRaster} of Digital Elevation Model (DEM).
#' @param checklist A data frame
#' @param method One of "range" or "checklist".
#' @importFrom terra rast extract nlyr vect writeVector
#' @importFrom CoordinateCleaner clean_coordinates
#' @importFrom checkmate assert checkClass checkChoice checkNumeric checkCharacter assertDataFrame checkList
#' @importFrom rnaturalearth ne_countries
#' @return a list
#' @details
#' For each coordinate pair of \emph{x} and \emph{y}, several tests are applied. First, the
#' function \link[CoordinateCleaner]{clean_coordinates} to control for the
#' misplacement of coordinates (e.g., over the center of countries, cities,
#' institutions providing access to the observation data). Second, \emph{g_ranges}
#' and \emph{e_ranges} are used to control, respectively, for expert knowledge
#' on the geographic and elevation ranges of species occurrences. If \emph{method}
#' is set to 'range', the content of \emph{g_ranges} is interpreted as an object
#' composed by multiple binary range maps, one for each unique element in
#' \emph{species}. Layers should be labeled with the respective species name. If
#' \emph{method} is set to 'checklist', \emph{g_ranges} is assumed to be a factorial
#' object. Note that the class names in the raster must correspond to those
#' in \emph{checklist}, which must also be provided as a 2-column data.frame
#' specifying the 'region'(s) of occurrence for each 'species'. When applying
#' either method, rows in \emph{x} are filtered if they are not supported by
#' the respective species geographic range/region and elevation range. Third,
#' a check evaluates whether each species observation, when buffered by its
#' coordinate precision, is contained in a pixel with the specified spatial
#' \emph{resolution}. This check is conducted over a regular global grid with
#' a resolution in degrees. When testing for containment, the precision of each
#' coordinate pair is inferred form the number of decimal places (as done in
#' \href{Open Street Map}{https://wiki.openstreetmap.org/wiki/Precision_of_coordinates}).
#' The final output is a list composed of:
#'  \describe{
#'    \item{flag}{logical vector with test results (TRUE for valid observations)}
#'    \item{reason}{character vector of reason for failing the test (one of
#'    'location', 'elevation range', 'geographic range', or 'pixel containment')}
#'    \item{precision}{numeric vector with an updated estimate of the precision
#'    of each coordinate pair.}
#'    \item{cell}{cell number overlapping the each coordinate pair based on a
#'    global raster grid with the specified resolution.}}
#' @export

#-----------------------------------------------------------------------------#

location_filter = function(x, y, e, species, iso2c, resolution,
                           g_ranges, e_ranges, elevation,
                           method="range", checklist=NULL) {

  # test arguments ----
  #---------------------------------------------------------------------------#

  assert(
    checkCharacter(x),
    checkCharacter(y),
    checkNumeric(e, len=nrow(x)),
    checkCharacter(species, len=nrow(x)),
    checkCharacter(iso2c, len=nrow(x)),
    checkList(e_ranges, len=length(unique(species))),
    checkClass(elevation, classes="SpatRaster"),
    checkChoice(method, choices=c("range","checklist")),
    checkClass(g_ranges, classes="SpatRaster"))

  if (method == "checklist")
    assertDataFrame(checklist, col.names=c("species","region"))

  # combine inputs
  x = as.data.frame(x)
  x$species = species
  x$iso = iso2c
  colnames(x) = c("x","y","iso")

  rm(species, iso2c)

  # download country shapefile is prompted (otherwise read)
  n = file.path(find.package("GlobES"), "extdata", "countries.shp")
  if (file.exists(n)) countries = vect(n) else {
    countries = vect(ne_countries("medium"))
    writeVector(countries, n)
  }

  # match elevation ranges with species ----
  #---------------------------------------------------------------------------#

  # convert input into data.frame
  n = names(e_ranges)
  e_ranges = as.data.frame(do.call(rbind, e_ranges))
  e_ranges$species = n
  colnames(e_ranges) = c("min","max","species")

  # match data.frame to species observations
  e_ranges = e_ranges[match(x$species,e_ranges$species),]

  # flag potentially erroneous coordinates ----
  #---------------------------------------------------------------------------#

  flags = clean_coordinates(x=x,lon="x", lat="y",
                            countries="iso", species=NULL,
                            tests = c("capitals", "centroids",
                                      "equal", "gbif", "institutions",
                                      "seas", "zeros"), verbose=F,
                            country_ref=countries)

  # distinguish valid observations
  check = flags$.summary
  rm(flags)

  # record reason for exclusion
  reason = rep(NA, length(check))
  reason[!check] = "location"

  # apply biogeographic tests ----
  #---------------------------------------------------------------------------#

  ## test elevation range ----
  ##==========================================================================#

  # extract elevation for each observation
  elev = extract(elevation, x[,c("x","y")], ID=F)[,1]

  # flag invalid observations
  check[which((elev < e_ranges$min) | (elev > e_ranges$max))] = FALSE
  reason[which(!check & is.na(reason))] = "elevation range"

  ## test geographic range ----
  ##==========================================================================#

  # define function interacting with input
  if (method == "range") {

    for (l in nlyr(g_ranges)) {

      # find observations to test
      ti = which(check & x$species == names(g_ranges)[l])

      # skip if there is no testing required
      if (length(ti) == 0) next

      # verify overlap with range map
      rm = extract(g_ranges[[l]], x[ti,c("x","x")], ID=F)[,1]

      # flag invalid observations
      check[ti[which(rm == 0)]] = FALSE

    }

  } else {

    # extract regional association
    loc = extract(g_ranges, x[,c("x","y")], ID=F)[,1]

    # check regional assocation
    sp = unique(x$species[check])
    for (s in 1:length(sp)) {

      # find entries to compare
      ti = which(check & x$species == sp[s])
      ri = which(checklist$species == sp[s])

      # verify that observations fall in target region
      check[ti[which(!loc[ti] %in% checklist$reigon[ri])]] = FALSE

    }
  }

  # record reason
  reason[which(!check & is.na(reason))] = "geographic range"

  # apply containment test ----
  #---------------------------------------------------------------------------#

  # target observations
  ti = which(check)

  # update coordinate precision
  e[ti] = coordinate_precision(as.matrix(x[ti,c("x","y")]), e[ti])

  # apply test
  flag = containment_test(as.matrix(x[ti,c("x","y")]), e[ti], resolution)

  # record evaluated map resolution
  a_res = rep(NA,length(check))
  a_res[ti] = flag$resolution

  # record test results
  check[ti[!flag$check]] = FALSE
  reason[which(!check & is.na(reason))] = "pixel containment"

  # record raster grid cell of valid observations
  cell = rep(NA, length(check))
  cell[ti[flag$check]] = flag$cell[flag$check]

  # compile and return results
  #---------------------------------------------------------------------------#

  return(list(flag=check, reason=reason, precision=e, cell=cell, resolution=a_res))

}
