library(rhandsontable)
library(shiny)
library(tidyverse)
library(stringr)
library(glue)
library(fs)

source("prep_data.R")

DF <- rubric

ui <- shinyUI(fluidPage(
    titlePanel(glue("{config$problem_set} Grading")),
    sidebarLayout(
        sidebarPanel(
            helpText(
                "Shiny app for grading Rmd files.",
                "Right-click on the table to delete/insert rows.",
                "Double-click on a cell to edit"
            ),
            br(),
            selectInput(
                "studentSelect",
                label = "Select Student:",
                choices = submissions$usc_id,
                selected = submissions$usc_id[1]
            ),
            br(),
            
            wellPanel(h3("Save table"),
                      div(
                          class = 'row',
                          div(class = "col-sm-6",
                              actionButton("save", "Save")),
                          div(class = "col-sm-6",
                              radioButtons("fileType", "File type", c("csv", "RDS"))),
                          div(class = "col-sm-6", 
                              textInput("savepath","Saved file path", value = getwd())),
                          div(class = "col-sm-6", 
                              textInput("outfilename","File name", value = glue("{config$problem_set}_grades_export")))
                      )),
            actionButton("cancel", "Cancel last action"),
            br(),
            br(),
            
            # rHandsontableOutput("hot", width = "600px", height = "500px"),
            div(rHandsontableOutput("hot", width = "600px", height = "500px"), style = "overflow:visible;"),
            br(),
            style = "position: fixed; overflow: visible;"
            
        ),
        
        mainPanel(tabsetPanel(
            tabPanel("HTML Output", htmlOutput("html_file")),
            tabPanel("Code Diff", htmlOutput("showfile"))
        ))
    )
))

server <- shinyServer(function(input, output) {
    values <- reactiveValues()
    
    ## Handsontable
    observe({
        # if there is existing input in the table...
        if (!is.null(input$hot)) {
            # store the current values and keep it in "previous"
            values[["previous"]] <- isolate(values[["DF"]])
            # convert hot to dataframe
            DF = hot_to_r(input$hot)
            # take our input and calculate the total and grade values
            DF <- DF %>% mutate(
                total = DF %>% select(starts_with("q")) %>% rowSums(.),
                grade = round(ifelse(total != 0, total /
                                         out_of, NA), 3))
        } else {
            if (is.null(values[["DF"]])){
                DF <- DF
                DF <- DF %>% mutate(
                    total = DF %>% select(starts_with("q")) %>% rowSums(.),
                    grade = round(ifelse(total != 0, total /
                                             out_of, NA), 3))
            }else{
                DF <- values[["DF"]]
                DF <- DF %>% mutate(
                    total = DF %>% select(starts_with("q")) %>% rowSums(.),
                    grade = round(ifelse(total != 0, total /
                                             out_of, NA), 3))
            }
                
        }
        values[["DF"]] <- DF
    })
    
    output$hot <- renderRHandsontable({
        DF <- values[["DF"]]
        if (!is.null(DF))
            rhandsontable(DF,
                          useTypes = F)
    })
    
    ## Save
    observeEvent(input$save, {
        fileType <- isolate(input$fileType)
        finalDF <- isolate(values[["DF"]])
        outdir <- isolate(input$savepath)
        outfilename <- isolate(input$outfilename)
        if (fileType == "ASCII") {
            dput(finalDF, file = file.path(outdir, sprintf("%s.txt", outfilename)))
        } else if ( fileType == "csv"){
            write_csv(finalDF, file = file.path(outdir, sprintf("%s.csv", outfilename)))
        }
        else{
            saveRDS(finalDF, file = file.path(outdir, sprintf("%s.rds", outfilename)))
        }
    })
    
    ## Cancel last action
    # Applies only to the table
    observeEvent(input$cancel, {
        if (!is.null(isolate(values[["previous"]])))
            values[["DF"]] <- isolate(values[["previous"]])
    })
    
    ### HTML FILE RENDERING LOGIC
    
    observeEvent(input$studentSelect,{
        output$showfile <- renderUI({
            usc_id <- isolate(input$studentSelect)
            path <- glue("{gradebook_folder_path}/{usc_id}")
            html_file <-
                list.files(path, "*html_diff.html", recursive = T)
            tags$iframe(
                src = glue("data/{usc_id}/{html_file}"),
                width = "100%",
                height = "100%",
                id = "html_diff",
                onload = "this.height=this.contentWindow.document.body.scrollHeight;"
            )
        })
        
        output$html_file <- renderUI({
            usc_id <- isolate(input$studentSelect)
            path <- glue("{gradebook_folder_path}/{usc_id}")
            html_file <- list.files(path, "*.html", recursive = T)
            html_file <-
                html_file[!grepl("_html_diff.html", html_file)]
            includeHTML(glue("{path}/{html_file}"))
            
        })
    })
    
    output$showfile <- renderUI({
            usc_id <- isolate(input$studentSelect)
            path <- glue("{gradebook_folder_path}/{usc_id}")
            html_file <-
                list.files(path, "*html_diff.html", recursive = T)
            tags$iframe(
                src = glue("data/{usc_id}/{html_file}"),
                width = "100%",
                height = "100%",
                id = "html_diff",
                onload = "this.height=this.contentWindow.document.body.scrollHeight;"
            )
    })
    
    output$html_file <- renderUI({
        usc_id <- isolate(input$studentSelect)
        path <- glue("{gradebook_folder_path}/{usc_id}")
        html_file <- list.files(path, "*.html", recursive = T)
        html_file <-
            html_file[!grepl("_html_diff.html", html_file)]
        includeHTML(glue("{path}/{html_file}"))
        
    })
    
    
})

## run app
runApp(list(ui = ui, server = server))
