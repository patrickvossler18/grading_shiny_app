# DATA PREP

library(tidyverse)
library(stringr)
library(glue)
library(shiny)
library(rhandsontable)
library(yaml)
library(fs)


make_rubric_df <- function(usc_id, num_rows, out_of, question_list) {
    as_tibble(matrix(
        rep(0, num_rows * length(question_list)),
        nrow = num_rows,
        ncol = length(question_list),
        dimnames = list(NULL, question_list)
    )) %>%
        mutate(
            usc_id = usc_id,
            total = rep(NA, num_rows),
            out_of = rep(out_of, num_rows),
            grade = rep(NA, num_rows),
            comment = rep("", num_rows),
        ) %>%
        select(usc_id, everything())
}

# POINT TO CONFIG FILE
config <- read_yaml("example_assignment/config.yml")

if(nchar(config$path_to_shiny_dir) == 0 | is.null(config$path_to_shiny_dir) ){
    config$path_to_shiny_dir = getwd()
}

gradebook_zip_file_path <- path(config$path_to_shiny_dir, config$problem_set,
                                config$gradebook_zip_file)
gradebook_folder_path <- substr(gradebook_zip_file_path,1,nchar(gradebook_zip_file_path)-4)

if(!dir.exists(gradebook_folder_path)){
    unzip(
        zipfile = gradebook_zip_file_path,
        exdir = path(config$path_to_shiny_dir, config$problem_set)
    )
    
}

# Tell the shiny app to make a symbolic link between gradebook_folder_path and the shiny app data folder
addResourcePath("data", gradebook_folder_path)

answer_write_up_path <-
    path(config$path_to_shiny_dir,
         config$problem_set,
         config$answer_write_up_file) %>% gsub("(\\s)", "\\\\\ ", .)

export_file <-
    path(config$path_to_shiny_dir,
         glue("{config$problem_set}_export.csv"))
# some students submit .rar files but I am not aware of a native R way to handle this
# have to manually unzip those files or grade them separately
submission_zips <-
    list.files(gradebook_folder_path, pattern = "*.zip")


if (!file.exists(export_file)) {
    submissions <- tibble(file = submission_zips)
    
    submissions <-
        submissions %>% mutate(
            usc_id = str_match(string = file, pattern = config$regex_pattern)[, 2],
            grade = NA,
            comment = ""
        )
} else{
    submissions <- read_csv(export_file)
}


if (config$extract_from_zip) {
    # extract all of the submissions into folders
    for (i in 1:nrow(submissions)) {
        usc_id <- submissions[i,]$usc_id
        path <- path(gradebook_folder_path, usc_id)
        # make the folder
        if (!dir.exists(path)) {
            dir.create(path)
        }
        # extract contents of zip archive
        unzip(
            zipfile = path(gradebook_folder_path, submissions[i, ]$file),
            exdir = path
        )
        
    }
    
}
if (config$generate_diffs) {
    print("generating html diffs")
    
    submissions$html_diff <-
        sapply(glue("{gradebook_folder_path}/{submissions %>% pull(usc_id)}") , function(x) {
            rmd_file <- list.files(x, "*.Rmd|RMD|rmd", recursive = T)[1]
            if (length(rmd_file) > 0) {
                submitted_file <-
                    gsub("\\((\\d)\\)",
                         "\\\\(\\1\\\\)",
                         glue("{x}/{rmd_file}"))
                submitted_file <- gsub("(\\s)", "\\\\\ ", submitted_file)
                template_path <- path(config$path_to_shiny_dir,'template.html') %>% gsub("(\\s)", "\\\\\ ", .)
                system(
                    glue(
                        "diff -u {answer_write_up_path} {submitted_file}  | diff2html --hwt {template_path} -i stdin -F {str_replace(submitted_file,'.Rmd|RMD|rmd','_html_diff.html')} -o stdout"
                    ),
                    ignore.stdout = T
                )
                return(str_replace(
                    submitted_file,
                    '.Rmd|RMD|rmd',
                    '_html_diff.html'
                ))
            }
            
        })
}


# need to load the grading rubric dataframe
if (file.exists(path(
    config$path_to_shiny_dir,
    config$problem_set,
    glue("{config$problem_set}_grades_export.csv")
))) {
    rubric <-
        read_csv(
            path(
                config$path_to_shiny_dir,
                config$problem_set,
                glue("{config$problem_set}_grades_export.csv")
            ),
            col_types = cols(
                .default = "d",
                usc_id = "c",
                comment = "c"
            )
        )
    
} else{
    rubric <-
        make_rubric_df(submissions$usc_id,
                       nrow(submissions),
                       config$out_of,
                       config$rubric)
}
