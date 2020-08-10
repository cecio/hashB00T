#!/usr/bin/python3

#
# hashB00T Installer
#
# ***DON'T USE IT***, unless you know what you are doing
#

import os
import ctypes
import sys
import struct

# Return free sector number. It looks for at least 5 consecutive
# free sectors...just to be sure (even if we aren't...)
# Why 5? I don't know...it looks reasonable... :-)
# And may be we skip the FAT backup sector at position 6...
def find_free(disk):

    i = 1
    free_num = 0
    free_buf = bytearray(512)

    while free_num < 5:
        os.lseek(disk, i * 512, os.SEEK_SET)
        sec = os.read(disk,512)
        if sec == free_buf:
            free_num += 1
        else:
            free_num = 0
        i += 1

    if free_num == 5:
        return i - 1
    else:
        return -1

ux = True

try:
    is_admin = os.getuid() == 0
except AttributeError:
    ux = False
    is_admin = ctypes.windll.shell32.IsUserAnAdmin() != 0

if is_admin is False:
    print('[!] You need to have root/Administrator privileges to run this script')
    sys.exit(1)

# Read current MBR and save it for backup
print('[+] Backing UP the MBR')
if ux == True:
    diskstr = '/dev/sda'
    disk = os.open(diskstr, os.O_RDONLY)
else:
    diskstr = r"\\.\PhysicalDrive0"
    disk = os.open(diskstr, os.O_RDONLY | os.O_BINARY)

curr_mbr = os.read(disk, 512)

bkp = open('mbr.bkp','wb')
bkp.write(curr_mbr)
bkp.close()

# Find free space
print('[+] Looking for free space')
target_sector = find_free(disk)

print('[+] Free space found at sector: ' + str(target_sector))

os.close(disk)

if target_sector > 254:
    print('[!] Mmmmh...the free sector found is greater than expected...please check manually. Exiting...')
    sys.exit(1)

# Read the hashB00T file
hash = open('hash.bin','rb').read()
hash = bytearray(hash)

# Patch the hashB00T with address of free sector and original partition table
# Assumes 63 sectors per track
sector_track = 63

# PATCH1: Patch the address to load original boot sector
hash[131] = target_sector % sector_track             # Sector
hash[132] = 0
hash[135] = int(target_sector / sector_track)        # Head

# PATCH2: Patch the address to load the VBR of current active partition
for act in ( 446, 462, 478, 494 ):
    if curr_mbr[act] == chr(0x80):
        # Active partition found
        hash[32] = curr_mbr[act + 2]
        hash[33] = curr_mbr[act + 3]
        hash[35] = curr_mbr[act + 1]
        break

for x in range(440,512):
    hash[x] = curr_mbr[x]

# ASK confirmation
print('[!] Applying modification to ---> ' + diskstr + ' <---')
print('[?] DANGER: Are you sure? This can destroy your disk. Reply \'yes\' if you want to continue')
if (sys.version_info > (3, 0)):
    choice = input(": ")
else:
    choice = raw_input(": ")

if choice != 'yes':
    sys.exit(1)
print('[?] DANGER: Really? You can still change your mind. Reply \'yes\' if you want to continue')
if (sys.version_info > (3, 0)):
    choice = input(": ")
else:
    choice = raw_input(": ")

if choice != 'yes':
    sys.exit(1)

print('[!] We\'re all gonna die!!!')

### Reopen disk for changes ###
if ux == True:
    disk = os.open(diskstr, os.O_RDWR)
else:
    disk = os.open(diskstr, os.O_RDWR | os.O_BINARY)

# Save the curr_mbr on the free sector
os.lseek(disk, 0, os.SEEK_SET)
os.write(disk, hash)

# Save the new MBR
os.lseek(disk, ( target_sector - 1 ) * 512, os.SEEK_SET)
os.write(disk,curr_mbr)

os.close(disk)

print('[!] Done. Put the backed up MBR on a USB stick before rebooting. Just in case.')
