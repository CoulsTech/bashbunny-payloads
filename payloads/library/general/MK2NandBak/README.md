# MK2NandBak

Author: CoulsTech

Version: 1.0

## Description

Backs up image the internal UDISK of the bash bunny to the SDHC

Stores image backup in /root/udisk/backups/nandf-backup-*.gz

## LED Status

LED FAIL: SDHC was not found in /dev/mmblk0

LED G: Mounting SDHC to /root/udisk and making relevant directories

LED SPECIAL: Device is actively backing up /dev/nandf, this can take up to X Minutes

LED FINISH:  Device Successfully completed the DD command, unmounted, and can now be ejected

## Configuration

None, all configuration should be standard for the Bash Bunny MK2 with SD card slot

## Requirements

Bash Bunny MK2 with current firmware

SDHC formatted in a format that internal OS of the Bunny can read

Stable 5V DC power

patience

## Accessing Backup

gunzip backups/nandf-backup-*.gz

sudo mkdir /mnt/image

sudo mount -o loop nandf-backup-* /mnt/image

cd /mnt/image