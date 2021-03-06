
# Create an object defining the geographic extent of the model domain

#### Set up ####

rm(list=ls())                                                   

Packages <- c("tidyverse", "sf", "stars", "rnaturalearth", "raster")                  # List handy packages
lapply(Packages, library, character.only = TRUE)                            # Load packages

source("./R scripts/@_Region file.R")                                       # Define project region 

world <- ne_countries(scale = "medium", returnclass = "sf") %>%             # Get a world map
  st_transform(crs = crs)                                                   # Assign polar projection

EEZ <- rocks <- read.csv("./Data/Rocks.csv") %>%                                   # Import coordinates
  rbind(slice_head(.)) %>%                                                  # Close the polygon by repeating first point
  as.matrix() %>%                                                           # Change format for shape()
  shape() %>%                                                               # Convert to sf
  st_transform(4326) 

GEBCO <- read_stars("../Shared data/GEBCO_2020.nc")
st_crs(GEBCO) <- st_crs(EEZ)
GFW <- raster("../Shared data/distance-from-shore.tif")

crop <- as(extent(-10, -2, -20, -12), "SpatialPolygons")
crs(crop) <- crs(GEBCO)

#GEBCO <- crop(GEBCO, crop)
GFW <- crop(GFW, crop)

mask <- readRDS("./Objects/Domains.rds") %>%  filter(Shore == "Offshore")

#### Create land ####

land <- matrix(c(-29.345, 0.917,
                 -29.345, 0.91,
                 -29.34, 0.91,
                 -29.34, 0.917,
                 -29.345, 0.917),
               ncol = 2, byrow = T) %>% 
  shape() %>% 
  st_transform(4326) 

#### Polygons based on depth ####

Depths <- GEBCO[EEZ] %>% 
  st_as_stars()

Depths[[1]][Depths[[1]] > units::set_units(0, "m") | Depths[[1]] < units::set_units(-600, "m")] <- NA

Depths[[1]][is.finite(Depths[[1]])] <- units::set_units(-600, "m")

Bottom <- st_as_stars(Depths) %>%
  st_as_sf(merge = TRUE) %>%
  st_make_valid() %>%
  group_by(GEBCO_2020.nc) %>%
  summarise(Depth = abs(mean(GEBCO_2020.nc))) %>%
  st_make_valid()

ggplot(Bottom) +
  geom_sf(aes(fill = Depth), alpha = 0.2) +
  theme_minimal()

#### Cut to domain ####

clipped <- st_difference(mask, st_transform(Bottom, crs = st_crs(mask)))

ggplot(clipped) +
  geom_sf(aes(fill = Depth), alpha = 0.5)

#### Format to domains object ####

## Because there is no hard bottom we have to force things to work by reimporting the offshore polygon
clipped <- readRDS("./Objects/Domains.rds") %>%  filter(Shore == "Offshore")

overhang <- transmute(clipped, 
                      Shore = "Offshore",
                      area = as.numeric(st_area(clipped)),
                      Elevation = exactextractr::exact_extract(raster("../Shared data/GEBCO_2020.nc"), clipped, "mean")) %>% 
  st_transform(crs = crs)

saveRDS(overhang, "./Objects/Overhang.rds")

