library(dplyr)
library(ggplot2)
library(patchwork)
library(gganimate)

source('foos.R')
source('read_data.R')


# state plots
purrr::walk(c('deaths','cases'),.f=function(x,data){
    p <- data%>%foo_plot(metric = x,label_by = 'state',path_by = 'state.abb',facet_by = 'state.region')
    ggsave(filename = glue::glue('state_{x}.png'),p,width=7,height=7)
  },data =state_input%>%foo_roll('state'))

# region plots

purrr::walk(c('deaths','cases'),.f=function(x,data){
  p <- data%>%
    foo_plot(metric = x,'state.region','state.region')
  ggsave(filename = glue::glue('region_{x}.png'),p,width=7,height=7)
},data = state_input%>%
  dplyr::group_by(state.region,date)%>%
  dplyr::summarise_at(vars(cases,deaths),list(sum))%>%
  foo_roll('state.region'))

# county plots
purrr::walk(c('deaths','cases'),.f=function(x,data){
  p <- data%>%
    split(.$state.region)%>%
    purrr::map(
      foo_plot,
      metric = x,
      label_by = 'county',
      path_by = 'county',
      facet_by = 'state',
      lab_scale = 10
    )

  purrr::iwalk(p,function(xx,y) ggsave(file = glue::glue('county_{gsub("\\\\s","_",y)}_{x}.png'),xx,width = 10,height = 10))

},data = county_input%>%foo_roll('county'))

## animation

dat_labs <- state_input%>%
  foo_roll('state')%>%
  dplyr::group_by(date)%>%
  dplyr::filter(deaths>max(deaths,na.rm = TRUE)/50)%>%
  dplyr::ungroup()

p_anim <- state_input%>%
  foo_roll('state')%>%
  dplyr::filter(!is.na(deaths_c))%>%
  dplyr::filter(date>as.Date('2020-03-01'))%>%
  dplyr::mutate(state.abb = ifelse(is.na(state.abb),'DC',state.abb))%>%
  ggplot(aes(x=deaths_c,y=deaths)) +
  geom_abline(intercept=0,slope=1)+
  geom_path(aes(group=state.abb,colour=as.numeric(date)),show.legend = FALSE) +
  geom_point(data = dat_labs,na.rm = TRUE) +
  ggrepel::geom_label_repel(aes(label = state.abb),
                            data = dat_labs,
                            nudge_x = 10,
                            segment.color = 'grey80',
                            size = 2,
                            na.rm = TRUE) +
  scale_y_log10()+
  scale_x_log10() +
  labs(y = 'New Deaths\n(7 Day Rolling Sum)',
       x = 'Total Deaths',
       caption = 'Date:{frame_along}'
  ) +
  viridis::scale_colour_viridis(direction = -1) +
  theme(axis.text = element_text(size=rel(0.5))) +
  facet_wrap(~state.region) +
  gganimate::transition_reveal(date) +
  gganimate::ease_aes('circular-out')

magick::image_write(gganimate::animate(p_anim,fps=5), path="states_death.gif")


