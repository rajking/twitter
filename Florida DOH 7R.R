library(stringr)
library(tidyverse)
library(lubridate)
library(ggthemes)
library(scales)
library(RColorBrewer)
library(ggrepel)
library(ggplot2)
library(reshape2)

#--------------Get Data---------------

#Data import from https://open-fdoh.hub.arcgis.com/search

fcaseline <- read_csv("https://opendata.arcgis.com/datasets/37abda537d17458bae6677b8ab75fcb9_0.csv")

fcases <- read_csv("https://opendata.arcgis.com/datasets/a7887f1940b34bf5a02c6f7f27a5cb2c_0.csv")

#re-opening dates
# ref: https://www.flgov.com/covid-19/

# FL phase 1: 
# restaurants & stores at limited capacity
# Most counties: 5/4/2020
# Palm Beach: 5/11/2020
# Miami-Date & Broward: 5/18/2020

# FL phase 2: 
# bars, movie theaters, entertainment
# most counties: 6/5/2020

# Governor orders
# Bars closed: 6/26/20
# desantis warns license suspension if bars/rest not following covid19 guidelines

#--------------Case Counts---------------

# Case count for Florida
Florida <- fcaseline %>%
  select(Case1) %>%
  rename (date = "Case1") %>%
  group_by(date) %>%
  mutate(cases = n()) %>% 
  mutate(name = "Florida") %>%
  filter(row_number() == 1) %>% #removes duplicate rows by filtering only 1st one
  ungroup() %>% 
  arrange(date) %>%
  mutate(cases = cumsum(cases))

# Case count for Jacksonville Metro Area
Jacksonville  <- fcaseline %>%
  select(Case1,County) %>%
  rename (date = "Case1") %>%
  rename (county = "County") %>%
  group_by(date) %>%
  filter(county == "Duval" | county == "St. Johns" | county == "Clay") %>%
  mutate(cases = n()) %>% 
  mutate(county = "Jacksonville") %>%
  filter(row_number() == 1) %>% #removes duplicate rows by filtering only 1st one
  rename (name = "county") %>%
  ungroup() %>% 
  arrange(date) %>%
  mutate(cases = cumsum(cases))

# Case count for Miami Metro Area  
Miami   <- fcaseline %>%
  select(Case1,County) %>%
  rename (date = "Case1") %>%
  rename (county = "County") %>%
  group_by(date) %>%
  filter(county == "Dade" | county == "Broward" | county == "Palm Beach") %>%
  mutate(cases = n()) %>% 
  mutate(county = "Miami") %>%
  filter(row_number() == 1) %>% #removes duplicate rows by filtering only 1st one
  rename (name = "county") %>%
  ungroup() %>% 
  arrange(date) %>%
  mutate(cases = cumsum(cases))

# Case count for Orlando Metro Area  
Orlando <- fcaseline %>%
  select(Case1,County) %>%
  rename (date = "Case1") %>%
  rename (county = "County") %>%
  group_by(date) %>%
  filter(county == "Orange" | county == "Osceola" | county == "Lake" | county == "Seminole") %>%
  mutate(cases = n()) %>% 
  mutate(county = "Orlando") %>%
  filter(row_number() == 1) %>% #removes duplicate rows by filtering only 1st one
  rename (name = "county") %>%
  ungroup() %>% 
  arrange(date) %>%
  mutate(cases = cumsum(cases))

# Case count for Tampa Metro Area  
Tampa <- fcaseline %>%
  select(Case1,County) %>%
  rename (date = "Case1") %>%
  rename (county = "County") %>%
  group_by(date) %>%
  filter(county == "Hillsborough" | county == "Pinellas" | county == "Pasco" | county == "Hernando") %>%
  mutate(cases = n()) %>% 
  mutate(county = "Tampa") %>%
  filter(row_number() == 1) %>% #removes duplicate rows by filtering only 1st one
  rename (name = "county") %>%
  ungroup() %>% 
  arrange(date) %>%
  mutate(cases = cumsum(cases))

# bind into one dataset
covidCases <- rbind(Florida,Miami,Orlando,Tampa,Jacksonville)
covidCases$date <- as.Date(covidCases$date,"%Y/%m/%d")


# remove most recent date (last 5 entries)
# covidCases<-head(covidCases[order(covidCases$date),],-5)
   
#------------Daily cases-------------
# New Daily Cases

lineData <- covidCases %>% 
  select (cases,name,date) %>% 
  group_by(name) %>%
  mutate(daily = cases - lag(cases)) %>%
  ungroup()  

lineDataDaily <- lineData %>% 
  arrange (name, date) %>% 
  group_by(name) %>% 
  filter (daily>=10) %>% 
  mutate(days = 1 + date - date[1L]) %>%
  mutate(yvar=daily)

lineDataRolling <- lineData %>%
  arrange (name, date) %>% 
  group_by(name) %>% 
  mutate(movave=round((daily+lag(daily)+lag(daily,2)+lag(daily,3)+lag(daily,4)+lag(daily,5)+lag(daily,6))/7)) %>%
  filter (movave>=10) %>% 
  mutate(days= 1 +date - date[1L]) %>%
  mutate(yvar=movave)


#plot function

colorBlindPal <- c("#E69F00", "#D55E00", "#009E73", "#56B4E9", "#CC79A7", "#0072B2")   
lastday <- as.numeric(max(lineDataRolling$days)+11)
xbreaks <- seq(10,lastday,by=10)
currentDate <- covidCases[[nrow(covidCases),1]]

plotformat <- function(var1) {
  list(
    geom_line(size=1), 
    geom_point(size=0.5), 
    xlab ("\n Number of days since 10th daily cases first recorded"),
    ylab ("New Cases \n"),
    geom_text_repel(data = var1 %>% 
                      filter(days == last(days)), aes(label = name, 
                                                      x = days + 0.2, 
                                                      y = yvar, 
                                                      color = name,
                                                      fontface=2), size = 5), 
    scale_y_continuous(trans = log10_trans(),
                       breaks = c(10, 20, 50, 100, 200, 500, 1000, 2000, 5000),labels = comma),
    scale_x_continuous(breaks = xbreaks),
    annotate(geom = "text", x = 0, y = 1800, 
             label = ".", color = "#333333", size=3),
    annotate(geom = "text", x = 7.5, y = 1400, 
             label = "Miami Counties: Dade, Broward, Palm Beach\n Tampa Counties: Hillsborough, Pinellas, Pasco, Hernando 
      Orlando Counties: Orange, Seminol, Osceola, Lake\n Jacksonville Counties: Duval, Clay, St.John\n", color = "#333333", size=3),
    coord_cartesian(xlim=c(0,lastday)), 
    scale_color_manual(values=colorBlindPal),
    ggtitle("Number of new cases in Florida\n", subtitle = "Seven-day rolling average of new cases, by number of days since 10th case"),
    theme_gdocs(),
    theme(text = element_text(size=13)),
    theme(legend.position = "none"),
    theme(legend.title=element_blank()),
    labs(caption = paste0("Data Source: FL DOH   |  Last updated: ", currentDate))
  )
}


phase1 <- function() {
  list(
    annotate("segment", linetype = "solid", lwd=1,x = 52, xend = 52, y = (659-35), yend = (659+35), color = "#333333"),
    annotate("segment", linetype = "solid", lwd=1,x = 51, xend = 51, y = (361-19), yend = (361+19), color = "#333333"),
    annotate("segment", linetype = "solid", lwd=1,x = 44, xend = 44, y = (25-1.3), yend = (25+1.3), color = "#333333"),
    annotate("segment", linetype = "solid", lwd=1,x = 45, xend = 45, y = (54-2.8), yend = (54+2.8), color = "#333333"),
    annotate("segment", linetype = "solid", lwd=1,x = 43, xend = 43, y = (16-0.85), yend = (16+0.85), color = "#333333")  
  )
}

plotformat_date <- function(var1) {
  list(
    geom_line(size=1), 
    geom_point(size=0.5), 
    xlab ("\n Date"),
    ylab ("New Cases \n"),
    geom_text_repel(data = var1 %>% 
                      filter(days == last(days)), aes(label = name, 
                                                      x = date, 
                                                      y = yvar, 
                                                      color = name,
                                                      fontface=2), size = 5), 
    scale_y_continuous(trans = log10_trans(),
                       breaks = c(10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000),labels = comma),
    annotate(geom = "text", x = currentDate-53, y = 5000, 
             label = "Miami Counties: Dade, Broward, Palm Beach\n Tampa Counties: Hillsborough, Pinellas, Pasco, Hernando 
      Orlando Counties: Orange, Seminol, Osceola, Lake\n Jacksonville Counties: Duval, Clay, St.John\n", color = "#333333", size=3),
    scale_x_date(labels=date_format("%d-%b"), limits=c(currentDate-60,currentDate+5)),
    scale_color_manual(values=colorBlindPal),
    ggtitle("Number of new cases in Florida\n", subtitle = "Seven-day rolling average of new cases"),
    theme_gdocs(),
    theme(text = element_text(size=13)),
    theme(legend.position = "none"),
    theme(legend.title=element_blank()),
    labs(caption = paste0("Data Source: FL DOH   |  Last updated: ", currentDate))
  )
}


bars <- function() {
  list(
    geom_vline(xintercept = as.Date("2020-06-05"), linetype = "dashed"),
    geom_vline(xintercept = as.Date("2020-06-26"), linetype = "dashed"),
  annotate(geom = "text", x = as.Date("2020-06-05"), y = 9000, 
           label = "Phase 2", color = "#333333", size=3),
  annotate(geom = "text", x = as.Date("2020-06-26"), y = 9000, 
           label = "Bars Closed", color = "#333333", size=3)
  )
}

#plot of daily cases, daily & 7-day rolling

plotdaily <- ggplot(data = lineDataDaily, aes(x=days, y=daily, color = name)) + plotformat(lineDataDaily)

plotrolling_all <- ggplot(data = lineDataRolling, aes(x=days, y=movave, color = name)) + plotformat(lineDataRolling) + phase1()

plotrolling <-ggplot(data = lineDataRolling, aes(x=date, y=movave, color = name)) + plotformat_date(lineDataRolling) + bars()

#-----case rate-------------

caserate <- fcases %>%
  select(COUNTYNAME,C_AllResTypes,PUIsTotal) %>%
  group_by(COUNTYNAME) %>%
  mutate(CaseRate = round(C_AllResTypes/PUIsTotal,3)) %>%
  arrange(desc(CaseRate)) %>%
  rename (county = "COUNTYNAME") %>%
  rename (positive = "C_AllResTypes") %>%
  rename (tested = "PUIsTotal") 
  

CR_Miami <- caserate %>%
  filter(county == "DADE" | county == "BROWARD" | county == "PALM BEACH") %>%
  mutate(Metro = "Miami") %>%
  arrange(desc(tested))

CR_Orlando <- caserate %>% 
  filter(county == "ORANGE" | county == "OSCEOLA" | county == "LAKE" | county == "SEMINOLE") %>%
  mutate(Metro = "Orlando") %>%
  arrange(desc(tested))

CR_Tampa <- caserate %>% 
  filter(county == "HILLSBOROUGH" | county == "PINELLAS" | county == "PASCO" | county == "HERNANDO") %>%
  mutate(Metro = "Tampa") %>%
  arrange(desc(tested))

CR_Jacksonville <- caserate %>% 
  filter(county == "DUVAL" | county == "ST. JOHNS" | county == "CLAY") %>%
  mutate(Metro = "Jacksonville") %>%
  arrange(desc(tested))

CR_Metro <- rbind(CR_Miami,CR_Orlando,CR_Tampa,CR_Jacksonville)
CR_Metro <- CR_Metro %>% select(Metro, county, CaseRate, tested, positive)

CRplot <- ggplot(CR_Metro, aes(x=county, y=CaseRate, fill=Metro, color=Metro)) + 
  geom_bar(stat="identity") +
  theme_bw() +
  facet_wrap(~ Metro, scales="free_x") +
  labs(y = "County",
       title = paste("Case Rate by Metro ",currentDate)) 

#melt
crdat = melt(CR_Metro, id.vars=c("county", "Metro"),
            measure.vars=c("tested", "positive"))

CRplot2 <- ggplot(crdat, aes(x=county, y=value, fill=variable)) + 
  geom_bar(position="stack", stat="identity") +
  theme_bw() +
  facet_wrap(~ Metro, scales="free_x") +
  labs(y = "County",
       title = paste("Case Rate by Metro ",currentDate)) 



#-------Save to file--------


csvFileName <- paste(currentDate," CaseRate.csv",sep="")
pngFileNameD <- paste(currentDate," Daily Cases, DOH.png",sep="")

write.csv(CR_Metro,file=csvFileName)

png(filename=pngFileNameD, width = 1280, height = 720)
plot(plotrolling)
dev.off()




