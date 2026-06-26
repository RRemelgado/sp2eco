library(shiny)
library(leaflet)
library(mapedit)

ui <- fluidPage(
  
  titlePanel("Spatial data loader"),
  
  sidebarLayout(
    
    sidebarPanel(
      width = 3,
      
      actionButton("use_test", "Use test data"),
      
      tags$hr(),
      
      textInput("csv_path", "CSV path", ""),
      textInput("dem_path", "Elevation model path", ""),
      textInput("lc_path", "Land cover path", ""),
      
      tags$hr(),
      
      h4("Extent selection"),
      actionButton("draw_extent", "Draw extent"),
      
      verbatimTextOutput("extent_out")
    ),
    
    mainPanel(
      leafletOutput("map", height = 600)
    )
  )
)

server <- function(input, output, session) {
  
  rv <- reactiveValues(
    csv_path = NULL,
    dem_path = NULL,
    lc_path = NULL,
    extent = NULL
  )
  
  # -----------------------------
  # TEST DATA BUTTON
  # -----------------------------
  observeEvent(input$use_test, {
    
    rv$csv_path <- "data/test.csv"
    rv$dem_path <- "data/test_dem.tif"
    rv$lc_path  <- "data/test_landcover.tif"
    
    updateTextInput(session, "csv_path", value = rv$csv_path)
    updateTextInput(session, "dem_path", value = rv$dem_path)
    updateTextInput(session, "lc_path", value = rv$lc_path)
  })
  
  # keep reactive sync
  observe({
    rv$csv_path <- input$csv_path
    rv$dem_path <- input$dem_path
    rv$lc_path  <- input$lc_path
  })
  
  # -----------------------------
  # MAP
  # -----------------------------
  output$map <- renderLeaflet({
    leaflet() |>
      addTiles() |>
      setView(lng = 15, lat = 50, zoom = 4)
  })
  
  # -----------------------------
  # DRAW EXTENT
  # -----------------------------
  observeEvent(input$draw_extent, {
    
    ext <- editMap(
      leaflet() |>
        addTiles() |>
        setView(lng = 15, lat = 50, zoom = 4)
    )
    
    # store drawn rectangle/polygon
    rv$extent <- ext$finished
    
  })
  
  output$extent_out <- renderPrint({
    rv$extent
  })
}

