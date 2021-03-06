# Author: Gina Li
# Adapted by: Ellen Considine
# Date: 7/6/18

# This script downloads data sets from NASA LAADS HTTPS server
'''
Prerequisites:
1) Download and install Python 2.7 (I recommend Anaconda 2)
Objective:
In this script, daily data sets from NASA LAADS are downloaded, then uploaded to the S3 bucket.
To Run:
1) Adjust the output_path, start_year, end_date, data_set_name, and collection_number
2) Adjust the AWS access key, secret access key, bucket name, and subdir (if uploading to an S3 bucket)
2) Run script with the correct Python interpreter that arcpy is installed on (the Python 2.7 that comes with ArcGIS)
Output:
Downloaded MODIS data sets (option to upload to S3 commented out, but can uncomment to implement)
'''

# from urllib2 import urlopen, URLError, HTTPError
import urllib.request
import urllib.error
import json
import re

import boto
from boto.s3.key import Key
import os

output_path = 'C:\\Users\elco2649\\Documents\\MAIAC_DATA\\'
start_year = 2008
end_year = 2018
data_set_name = "MCD19A2"

collection_number = 6

# Amazon Key ID and Secret Key ID
keyId = ""
sKeyId = ""
bucketName = "earthlab-reid-group"
subdir = "MAIAC-AOD/collected_data/"


def dlfile(url, hdf_filename):
    # Open the url
    try:
        f = urllib.request.urlopen(url)
        print ("downloading " + url)

        # Open our local file for writing
        with open(output_path + hdf_filename, "wb+") as local_file:
            local_file.write(f.read())
            print("Uploading to S3...")
            uploadToS3Bucket(hdf_filename, local_file, subdir)

    # handle errors
    except(urllib.error.HTTPError, e):
        print ("HTTP Error:", e.code, url)
    except(urllib.error.URLError, e):
        print ("URL Error:", e.reason, url)


def uploadToS3Bucket(hdf_filename, file, subdir):
    conn = boto.connect_s3(keyId, sKeyId)
    bucket = conn.get_bucket(bucketName)
    # Get the Key object of the bucket
    k = Key(bucket)
    # Crete a new key with id as the name of the file
    k.key = subdir + hdf_filename
    # Upload the file
    k.set_contents_from_file(file, rewind=True)
    # os.remove(output_path + hdf_filename)


def isLeapYear(year):
    if year % 4 == 0:
        if year % 100 == 0:
            if year % 400 == 0:
                return True
            else:
                return False
        else:
            return True
    else:
        return False


def main():
    # Iterate over years of interest
    for year in range(start_year, end_year + 1):
        if isLeapYear(year):
            end_date = 366
        else:
            end_date = 365
        # Iterate over all dates in year
        for julian_day in range(1, end_date + 1):
            print("Downloading data sets for year " + str(year) + " and julian day " + str(julian_day))
            julian_day = str(julian_day).zfill(3)
            # construct base URL with correct year and date
            base_url = ("https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/%d/%s/%d/%s" % (
                collection_number, data_set_name, year, julian_day))
            # construct link to json file with list of all HDF files for a given date
            hdf_list = base_url + ".json"
            response = urllib.request.urlopen(hdf_list)
            # Read in list of all HDF files for given date
            json_str = response.read()
            parsed_json = json.loads(json_str)
            # Geography of US:
            tiles = ["h08v04", "h08v05", "h08v06", "h09v04", "h09v05", "h09v06", "h10v04", "h10v05"]
            # Get the name of each HDF file
            for j in parsed_json:
                hdf_filename = j['name']
                # print(hdf_filename)
                split_name = re.split('[.]', hdf_filename)
                # print(split_name)
                geog = split_name[2]
                # print("Geog = " + geog)
                if (geog in tiles):
                    print("hdf_filename: " + hdf_filename)
                    url = base_url + "/" + hdf_filename
                    dlfile(url, hdf_filename)
                    os.remove(output_path + hdf_filename)
      

if __name__ == '__main__':
    main()
