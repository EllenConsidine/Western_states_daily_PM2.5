To process the MAIAC data, we used the MODIS Reprojection Tool (MRT) in addition to several Python scripts.

The MRT User's Manual: https://lpdaac.usgs.gov/sites/default/files/public/mrt41_usermanual_032811.pdf
Note: we used the MRT GUI (locally) to generate the parameter files for the automated batch processing on EC2. 
Installation instructions are detailed in the above User's Manual. 

Processing:

On EC2: (docker run -it earthlab/modis-reprojection-tool)

download_from_https.py
MRT_step1.py
MRT_step2.py

On computer with ArcGIS installed:
MRT_step3.py