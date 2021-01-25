library(tidyverse)
library(glue)
library(rlang)
library(fs)

gradebook_file = "gc_20201_buad_312_mm-jb_column_2020-05-16-12-04-29.csv"
PS_name = "PS8"
gradebook <- read_csv(glue("~/Dropbox/grading_shiny_app/{PS_name}/{gradebook_file}"))


BB_PS_name = "Problem Set 8 [Total Pts: 10 Score] |2010470" # This is the column name for the assignment in the grade center
BB_comment_name = "Feedback to Learner" # This is the column name for comments that blackboard expects

export_file = "PS8_grades_export - Final.csv"
export_file_path = glue("~/Dropbox/grading_shiny_app/{PS_name}")

grades <- read_csv(path(export_file_path,export_file)) %>%
    dplyr::distinct(usc_id,.keep_all=T) %>%
    mutate(comment = ifelse(comment == "1",str_remove_all(comment,"1"),comment)) %>% 
    mutate(comment = ifelse(is.na(comment),"",comment))


gradebook_w_grades <- gradebook %>% 
    left_join(y=grades, by = c("Username" = "usc_id")) %>%
    mutate(!!BB_PS_name := ifelse(!is.na(grade),round(grade * 10,2),""), # NOTE: This might be redundant for assignments already only out of 10 points
           !!BB_comment_name := ifelse(is.na(comment),"", comment)) %>%
    select(-one_of(colnames(grades)))

write_csv(gradebook_w_grades,
          path(export_file_path,glue("{PS_name}_gradebook_with_grades.csv")),
          na = "")
