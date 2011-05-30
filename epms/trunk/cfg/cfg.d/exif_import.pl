#######################################################
###                                                 ###
###      EXIF Metadata Extractor for EPrints 3      ###
###                                                 ###
#######################################################
###                                                 ###
###             Developed by David Tarrant          ###
###                                                 ###
###          Released under the GPL Licence         ###
###           (c) University of Southampton         ###
###                                                 ###
#######################################################

# ABSOLUTE path to exiftool
# It is advisable to use exiftool rather than the perl EXIF library as exiftool is a LOT better.

$c->{"exif_import"}->{"exif_path"} = '/usr/bin/exiftool';
