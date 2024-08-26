# batch-DVD-ISO-2-mp4
How to encode 150 DVDs easily and get Telegram notifications while it's working for you

## How it works 

### STEP 1

Create a /ISO folder with all your ISOs

### STEP 2

As a precaution (like for example ISOs in the middle of a transfer) you have a *known_iso.txt* file that declares all available ISOs to encode.

You can auto-generate it with *known_iso_generator.sh*

### STEP 3 

*autoencodeiso.sh* mounts one ISO, gets all the VOB files, encodes them and puts them in a /ISO-encoded/{NAME} folder

When done, it add the name to the *encoded_disks.txt* file

### STEP 4 

*autoconcatmp4.sh* for every line of encoded_disk.txt gets all mp4 generated in the {NAME} subfolder, and creates a mp4 with chapters

It adds the {NAME} to a list of *processed_mp4.txt* file not to generate them again

### STEP 5 

You can compare the ISOs to the MP4s, to see how many are missing, you can use *compare_iso_mp4.sh*
