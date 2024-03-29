

#' Send query to dbh api
#' Help function which send query form r to api, it is designes in the way that it looks like api query and allows the same functionality as in api
#'
#' @param tabell_id 
#' @param filters 
#' @param group_by 
#' @param sort_by 
#' @param exclude 
#'
#' @return query 
#' @export
#'
#' @examples
dbh_json_query <-
  function(tabell_id,
           filters = list(),
           group_by = list(),
           sort_by = list(),
           exclude = NULL) {
    
    filter_query <- list()
    exclude_warning <- character(0)
      
      for (i in seq_along(filters)) {
        filter_query[[i]] <-
          list(variabel = enc2utf8(names(filters)[i]),
               selection = list(filter = "item",
                                values = lapply(filters[[i]],
                                                function(s) enc2utf8(as.character(s)))))
        if (filters[[i]][1] == "*") {
          filter_query[[i]]$selection$filter <- "all"
          if (names(filters)[i] %in% names(exclude)) {
            filter_query[[i]]$selection$exclude = lapply(exclude[[names(filters)[i]]],
                                                         function(s) enc2utf8(as.character(s)))
          }
        } else if (filters[[i]][1] %in% c("top",  "lessthan", "greaterhan")) {
          filter_query[[i]]$selection$filter <- filters[[i]][1] 
          filter_query[[i]]$selection$values <- lapply(filters[[i]][2],
                                                       function(s) enc2utf8(as.character(s)))
          if (names(filters)[i] %in% names(exclude)) {
            filter_query[[i]]$selection$exclude = lapply(exclude[[names(filters)[i]]],
                                                         function(s) enc2utf8(as.character(s)))
          }
        } else if (filters[[i]][1] == "between") {
          filter_query[[i]]$selection$filter <- "between"
          filter_query[[i]]$selection$values <- c(lapply(filters[[i]][2],
            function(s) enc2utf8(as.character(s))),lapply(filters[[i]][3],
              function(s) enc2utf8(as.character(s))))
          if (names(filters)[i] %in% names(exclude)) {
            filter_query[[i]]$selection$exclude = lapply(exclude[[names(filters)[i]]],
                                                         function(s) enc2utf8(as.character(s)))
          }
        } else if (names(filters)[i] %in% names(exclude)) {
          exclude_warning <-
            paste0(ifelse(length(exclude_warning) == 0,
                          "Excluding filters cannot be combined with the item filter for the following variables: ",
                          paste0(exclude_warning, ", ")),
                   names(filters)[i])
        }
      }
    
    if (length(exclude_warning) != 0) warning(exclude_warning)
    
    return(list(tabell_id = tabell_id ,
                groupBy = lapply(group_by, function(s) enc2utf8(as.character(s))),
                sortBy = lapply(sort_by, function(s) enc2utf8(as.character(s))),
                filter = filter_query))
  }


#'  Get data from dbh api as R dataframe
#'  A function send request from R to api and get data from api into R.
#'  Data are converted in right format using helepfunction dbh_metadata
#'  For token users it is possible to get token using function get_dbh_token and us it further
#'  
#'
#' @param tabell_id a code name for dataset
#' @param filters is the same as filters in dbh api: item, all, top, between, lessthan
#' @param group_by group by variables in the same way as in dbh api
#' @param sort_by sort variables
#' @param exclude 
#' @param api_versjon 
#' @param statuslinje 
#' @param decimal_separator 
#' @param meta is set to FALSE and does not return metadata
#'
#' @return R dataframe
#' @export
#'
#' @examples retrieve data set form bulk data : dbh_tabell(907)
#' use filtering to get data set dbh_tabell(373, filters=list(Årstall=c("top", "5")), group_by="Årstall)
dbh_tabell <- function(tabell_id,
  filters=NULL,
  group_by = NULL,
  sort_by = NULL, exclude =NULL, 
  api_versjon=1, 
  statuslinje="N",
  decimal_separator = readr::locale()$decimal_mark,
  meta=FALSE) {
  if (is.null(filters)) {
    url <- paste("https://api-stage.nsd.no/dbhapitjener/Tabeller/bulk-csv-stream?rptNr=", tabell_id, sep = "") 
    
    res <- httr::GET(url, httr::add_headers(Authorization = paste("Bearer", dbh_api_token(), sep = " ")))
    status <- res$status_code
    res <- httr::content(res, as = "text")
    
    if (status == 200) {
      data = readr::read_delim(res,
        delim = ",",
        col_types = readr::cols(.default = readr::col_character()),
        locale = readr::locale(decimal_mark = "."),
        na = "",
        trim_ws = TRUE, progress = readr::show_progress()
      )
    }
    else {return(status)}
  }
  else {
    spørring <- dbh_json_query(tabell_id = tabell_id, filters = filters, group_by = group_by, sort_by = sort_by, exclude = exclude)
    post_body = rjson::toJSON(c(list(
      api_versjon = api_versjon,
      statuslinje = statuslinje,
      decimal_separator = decimal_separator),
      spørring))
    
    
    resultat <- httr::POST(url = "https://api.nsd.no/dbhapitjener/Tabeller/hentCSVTabellData",
      httr::add_headers(`Content-Type` = "application/json", Authorization = paste("Bearer", dbh_api_token(), sep =  " ")),
      body = post_body,
      encode = 'json' )
    status <- resultat$status_code
    resultat <- httr::content(resultat, as = "text")
    if (status == 200) {
      data = readr::read_delim(resultat,
        delim = ";",
        col_types = readr::cols(.default = readr::col_character()),
        locale = readr::locale(decimal_mark = decimal_separator),
        na = "",
        trim_ws = TRUE, progress = readr::show_progress()
      )
    }
    else{
      return(status)
    }
    
  }
  metadata <- dbh_metadata(tabell_id = tabell_id)
  for (i in seq_along(names(data))) {
    if (isTRUE(metadata[["Numeric_variable"]][match(names(data)[i], metadata[["Variabel navn"]])])) 
    {
      
      data[[i]] <- as.numeric(data[[i]])
    }
  }
  if (meta == TRUE) {
    return(list(data, metadata))}
  else {
    return(data)
  }
  
}


