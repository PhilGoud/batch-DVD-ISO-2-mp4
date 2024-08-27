# batch-DVD-ISO-2-mp4
How to archive 150 DVDs easily in mp4 and get Telegram notifications while it's working for you

## Requirements
- HandbrakeCLI
- ffmpeg

## How it works :

{ISO folder} => {temp folder} => {destination folder}

### Step 1

Create a {ISO folder} with all your ISOs

### Step 2

You need a *known_iso.txt* file that declares all available ISOs to encode.

You can auto-generate it with *known_iso_generator.sh*

### Step 3 

*autoencodeiso.sh* mounts one ISO, gets all the VOB files, encodes them and puts them in a /{temp folder}/{NAME} folder

When done, it add the name to the *encoded_disks.txt* file generated in the {temp folder}

### Step 4 

*autoconcatmp4.sh* for every line of encoded_disk.txt gets all mp4 generated in the /{temp folder}/{NAME} subfolder, and creates 
1 - a mp4 with all VOB files
2 - if multiple tracks, one mp4 per track
3 - if menu videos, one mp4 with the menus
All will be sent to your {destination folder}

It adds the {NAME} to a list of *processed_mp4.txt* file not to generate them again

### Step 5 

You can compare the ISOs to the MP4s, to see how many are missing, you can use *compare_iso_mp4.sh*

If you want to be throrough, you can compare the VOB in the ISO files to the mp4 in the {temp folder} with *compare_vob_mp4.sh*

## Notes

### Why Handbrake and ffmpeg and not just one of them ?
Because desinterlacing with Handbrake is waaay easier to configure to have a good result

### Why are the files so huge ?
My purpose here is to archive family DVDs, so i want to be able to have a kind of "Master" as close to DVD quality as possible, even a little bit better via post-treatment.

### Why those txt files ?
As you are transfering the ISO or encoding mp4, you don't want the scripts to start working on these partial files. So I use these files to tell that is is ready to be treated.

### Why not a single script with encode and concat ?
Because it allow more flexibility and checks, as for example comparing the VOB files in the ISOs to the MP4 files created in the {temp folder}
