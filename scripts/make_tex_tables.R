# Set dir
setwd(githubdir)
setwd("birthday_voter/")

# load libs
library(tidyverse)
library(readr)
library(xtable)

# Table 1
tab1 <- read_csv("tabs/tab1_filters.csv")

# Print
print(xtable(tab1,
               label = "table:filter",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab1_filters.tex")

# Table 2
tab2 <- read_csv("tabs/tab2_midterms_vs_pres.csv")

# Print
print(xtable(tab1,
               label = "table:midterm_pres",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab2_midterms_vs_pres.tex")

# Table 3
tab3 <- read_csv("tabs/tab3_pri_vs_gen.csv")

# Print
print(xtable(tab3,
               label = "table:pri_gen",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab3_pri_vs_gen.tex")

# Table 4
tab4 <- read_csv("tabs/tab4_summary_table.csv")

# Print
print(xtable(tab4,
               label = "table:tab4",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab4_summary_table.tex")

# Table 5
tab5 <- read_csv("tabs/tab5_avg_abs_chg_from_prev_day_7d_window.csv")

# Print
print(xtable(tab5,
               label = "table:tab5",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab5_avg_abs_chg_from_prev_day_7d_window.tex")
# Table 6
tab6 <- read_csv("tabs/tab6_avg_abs_chg_from_prev_day_30d_window.csv")

# Print
print(xtable(tab6,
               label = "table:tab6",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab6_avg_abs_chg_from_prev_day_30d_window.tex")

# Table 7
tab7 <- read_csv("tabs/tab7_avg_abs_chg_from_prev_day_50d_window.csv")

# Print
print(xtable(tab7,
               label = "table:tab7",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab7_avg_abs_chg_from_prev_day_50d_window.tex")

# Table 8
tab8 <- read_csv("tabs/tab8_avg_abs_chg_from_prev_day_7d_window_groupby_race.csv")

# Print
print(xtable(tab8,
               label = "table:tab8",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab8_avg_abs_chg_from_prev_day_7d_window_groupby_race.tex")

# Table 9
tab9 <- read_csv("tabs/tab9_avg_abs_chg_from_prev_day_30d_window_groupby_race.csv")

# Print
print(xtable(tab9,
               label = "table:tab9",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab9_avg_abs_chg_from_prev_day_30d_window_groupby_race.tex")
# Table 10
tab10 <- read_csv("tabs/tab10_avg_abs_chg_from_prev_day_50d_window_groupby_race.csv")

# Print
print(xtable(tab10,
               label = "table:tab10",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab10_avg_abs_chg_from_prev_day_50d_window_groupby_race.tex")
# Table 11
tab11 <- read_csv("tabs/tab11_groupby_ballot_type_pct_chg_n_voters_from_prev_day_7d_window.csv")

# Print
print(xtable(tab11,
               label = "table:tab11",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab11_groupby_ballot_type_pct_chg_n_voters_from_prev_day_7d_window.tex")
# Table 12
tab12 <- read_csv("tabs/tab12_groupby_ballot_type_pct_chg_n_voters_from_prev_day_30d_window.csv")

# Print
print(xtable(tab12,
               label = "table:tab12",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab12_groupby_ballot_type_pct_chg_n_voters_from_prev_day_30d_window.tex")
# Table 13
tab13 <- read_csv("tabs/tab13_groupby_ballot_type_pct_chg_n_voters_from_prev_day_50d_window.csv")

# Print
print(xtable(tab13,
               label = "table:tab13",
               caption = "Effect of Data Quality Filters on the Number of Observations"), 
               caption.placement = "top",
               size = "\\small",
               include.rownames = F,
               heading_command = NULL,
               sanitize.text.function = function(x) {x},
               table.placement = "!htb",
               file = "tabs/tab13_groupby_ballot_type_pct_chg_n_voters_from_prev_day_50d_window.tex")
