## Introduction

We leverage data on millions of people using Florida state voter registration files to estimate whether people turn out more often if their birthday falls on the voting day. We conjecture that people see voting as a duty, and like doing dutiful things on their birthdays. To the extent that is true, it gives us evidence for voting as a duty. In addition, voting more frequently on birthdays may also be driven by people taking the day off on their birthdays and using the time to vote. To the extent that is the reason behind it, making election day an official holiday would increase turnout.

## Data Files

The dataset was extracted as of February 2017 and includes 10 years of elections from 2006 through 2016. There are two files.

### Official voter registration information
Data is extracted from the Florida Voter Registration System and includes information on voters who are officially registered or pre-registered as of the end of the prior month. All information is included except limited in those cases in which a voter requested exemption from public disclosure per Section 119.071, Fla. Stat.  (Section 98.0981(1)(b), Fla. Stat.).

### Unofficial voting history information
Data is extracted from independently submitted reports from the 67 county supervisors of elections capturing voting history at a fixed point in time. 

## Data Validation

We apply a set of filters to ensure that only persons at least 18 years old and registered to vote on election day are included in the analysis. We also perform a set of validation checks to confirm the soundness and accuracy of the dataset.

**Fake Birthdays**: we search for potential fake birthdays by identifying a month and day of year with a high number of occurrences (e.g. if an unusually high number of voters brithdays fall on a specific day).

**Voter turnout grouped by age**: we expect to see turnout initially go down until mid 20s, then increase steadily until about 70-80 years before declining.

**Voter turnout during midterms vs. presidential elections**: we expect to see higher turnout for presidential elections than midterms.

**Voter turnout during general vs. primary elections**: we expect to see higher turnout for general elections than primaries.

The dataset passed the validation checks. For the purposes of this analysis, we also limit the data to primary and general elections receiving at least 100 thousand votes.

## Analysis

We get the cartesian product of the voter registration file and the voting history file, such that primary key of the dataset is voter_id | election_type | election_date. We then group by the number of days between the person’s birthday and the election date, and calculate the mean change in voter turnout from the previous day. The analysis shows a substantial increase in turnout if election day falls on the voter’s birthday, as displayed in figure 1.

Tables 1, 2 and 3 show the mean absolute change in turnout for when the election date falls +/- 50 days,+/-  30 days, and +/- 7 days from the voter’s birthday compared to when the election falls on the voter’s birthday. In all three cases, the change in turnout from the previous day is more than two times greater when election date falls on the voter’s birthday.

## Conclusion

Further research may be warranted to determine the causal relationship between a person’s birthday and voting, which may be a result of a sense of duty, having more leisure time, or simply making it easier to remember. Whatever the case may be, our analysis shows that a person is in fact more likely to vote when election day falls on their birthday. 
