// A high level reference model for debugging FAT filesystems in boot.asm

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/*
    Simple boolean type for clarit,y since C doesn't have one built-in
*/
typedef uint8_t bool;
#define true 1
#define false 0

/*
    FAT12 Boot Sector layout.
    This structure is packed so it matches the exact on-disk format.
*/
typedef struct // The directory entry structure
{
    uint8_t  BootJumpInstruction[3];
    uint8_t  OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t  SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t  FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t  MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    uint8_t  DriveNumber;
    uint8_t  _Reserved;
    uint8_t  Signature;
    uint32_t VolumeId;
    uint8_t  VolumeLabel[11];
    uint8_t  SystemId[8];

} __attribute__((packed)) BootSector; // Ensure that padding is not adding to the data structure

/*
    FAT12 directory entry layout.
    Each entry represents a file or directory in the root directory.
*/
typedef struct
{
    uint8_t  Name[11];
    uint8_t  Attributes;
    uint8_t  _Reserved;
    uint8_t  CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} __attribute__((packed)) DirectoryEntry;

/*
    Global filesystem state
*/
BootSector     g_BootSector;
uint8_t*       g_Fat = NULL;
DirectoryEntry* g_RootDirectory = NULL;
uint32_t       g_RootDirectoryEnd;

/*
    Reads the boot sector from disk into memory.
*/
bool readBootSector(FILE* disk)
{
    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk) > 0;
}

/*
    Reads one or more sectors starting at a given LBA.
*/
bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut)
{
    bool ok = true;
    ok = ok && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0); // Seek to the correct position in the file
    ok = ok && (fread(bufferOut,
                      g_BootSector.BytesPerSector,
                      count,
                      disk) == count); // Read the X number of sectors into the output buffer
    return ok;
}

/*
    Loads the FAT into memory so cluster chains can be followed.
*/
bool readFat(FILE* disk)
{
    g_Fat = (uint8_t*)malloc(
        g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector
    );

    return readSectors(
        disk,
        g_BootSector.ReservedSectors,
        g_BootSector.SectorsPerFat,
        g_Fat
    );
}

/*
    Loads the root directory into memory.
*/
bool readRootDirectory(FILE* disk)
{
    uint32_t lba =
        g_BootSector.ReservedSectors +
        g_BootSector.SectorsPerFat * g_BootSector.FatCount;

    uint32_t size =
        sizeof(DirectoryEntry) * g_BootSector.DirEntryCount;

    uint32_t sectors = size / g_BootSector.BytesPerSector;
    if (size % g_BootSector.BytesPerSector)
        sectors++;

    g_RootDirectoryEnd = lba + sectors;

    g_RootDirectory = (DirectoryEntry*)
        malloc(sectors * g_BootSector.BytesPerSector); // Allocate enough space for the root directory

    return readSectors(disk, lba, sectors, g_RootDirectory); // Read the root directory into memory (Root sector function only reads full sectors, so ensure enough memory for no overflowing)
}

/*
    Searches the root directory for a file with a matching FAT 8.3 name.
*/
DirectoryEntry* findFile(const char* name)
{
    for (uint32_t i = 0; i < g_BootSector.DirEntryCount; i++)
    {
        if (memcmp(name, g_RootDirectory[i].Name, 11) == 0)
            return &g_RootDirectory[i];
    }
    return NULL;
}

/*
    Reads a file by following its FAT cluster chain.
*/
bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer)
{
    bool ok = true;
    uint16_t currentCluster = fileEntry->FirstClusterLow;

    do
    {
        uint32_t lba =
            g_RootDirectoryEnd +
            (currentCluster - 2) * g_BootSector.SectorsPerCluster;

        ok = ok && readSectors(
            disk,
            lba,
            g_BootSector.SectorsPerCluster,
            outputBuffer
        );

        outputBuffer +=
            g_BootSector.SectorsPerCluster *
            g_BootSector.BytesPerSector;

        uint32_t fatIndex = currentCluster * 3 / 2;

        if (currentCluster % 2 == 0)
            currentCluster =
                (*(uint16_t*)(g_Fat + fatIndex)) & 0x0FFF;
        else
            currentCluster =
                (*(uint16_t*)(g_Fat + fatIndex)) >> 4;

    } while (ok && currentCluster < 0x0FF8);

    return ok;
}

int main(int argc, char** argv)
{
    if (argc < 3)
    {
        printf("Syntax: %s <disk image> <file name>\n", argv[0]);
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb");
    if (!disk)
    {
        fprintf(stderr, "The disk image cannot be opened %s\n", argv[1]);
        return -1;
    }

    if (!readBootSector(disk))
    {
        fprintf(stderr, "Failed to read boot sector\n");
        return -2;
    }

    if (!readFat(disk))
    {
        fprintf(stderr, "Failed to read FAT\n");
        free(g_Fat);
        return -3;
    }

    if (!readRootDirectory(disk))
    {
        fprintf(stderr, "Failed to read root directory\n");
        free(g_Fat);
        free(g_RootDirectory);
        return -4;
    }

    DirectoryEntry* fileEntry = findFile(argv[2]);
    if (!fileEntry)
    {
        fprintf(stderr, "File not found: %s\n", argv[2]);
        free(g_Fat);
        free(g_RootDirectory);
        return -5;
    }

    uint8_t* buffer = (uint8_t*)
        malloc(fileEntry->Size + g_BootSector.BytesPerSector);

    if (!readFile(fileEntry, disk, buffer))
    {
        fprintf(stderr, "Failed to read file\n");
        free(buffer);
        free(g_Fat);
        free(g_RootDirectory);
        return -6;
    }

    for (size_t i = 0; i < fileEntry->Size; i++)
    {
        if (isprint(buffer[i]))
            fputc(buffer[i], stdout);
        else
            printf("<%02x>", buffer[i]);
    }
    printf("\n");

    free(buffer);
    free(g_Fat);
    free(g_RootDirectory);
    return 0;
}