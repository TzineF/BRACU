#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define FS_MAGIC 0x56534653U
#define JOURNAL_MAGIC 0x4A524E4CU  // "JRNL"

#define BLOCK_SIZE        4096U
#define INODE_SIZE         128U
#define JOURNAL_BLOCK_IDX    1U
#define JOURNAL_BLOCKS      16U
#define INODE_BLOCKS         2U
#define DATA_BLOCKS         64U
#define INODE_BMAP_IDX     (JOURNAL_BLOCK_IDX + JOURNAL_BLOCKS)
#define DATA_BMAP_IDX      (INODE_BMAP_IDX + 1U)
#define INODE_START_IDX    (DATA_BMAP_IDX + 1U)
#define DATA_START_IDX     (INODE_START_IDX + INODE_BLOCKS)
#define TOTAL_BLOCKS       (DATA_START_IDX + DATA_BLOCKS)
#define DEFAULT_IMAGE "vsfs.img"

#define REC_DATA   1
#define REC_COMMIT 2

#define NAME_LEN 28

#define INODE_TYPE_FREE 0
#define INODE_TYPE_FILE 1
#define INODE_TYPE_DIR  2

struct superblock {
    uint32_t magic;
    uint32_t block_size;
    uint32_t total_blocks;
    uint32_t inode_count;
    uint32_t journal_block;
    uint32_t inode_bitmap;
    uint32_t data_bitmap;
    uint32_t inode_start;
    uint32_t data_start;
    uint8_t  _pad[128 - 9 * 4];
};

struct inode {
    uint16_t type;
    uint16_t links;
    uint32_t size;
    uint32_t direct[8];
    uint32_t ctime;
    uint32_t mtime;
    uint8_t _pad[128 - (2 + 2 + 4 + 8 * 4 + 4 + 4)];
};

struct dirent {
    uint32_t inode;
    char name[NAME_LEN];
};

struct journal_header {
    uint32_t magic;
    uint32_t nbytes_used;
};

struct rec_header {
    uint16_t type;
    uint16_t size;
};

struct data_record {
    struct rec_header hdr;
    uint32_t block_no;
    uint8_t data[BLOCK_SIZE];
};

struct commit_record {
    struct rec_header hdr;
};

static void die(const char *msg) {
    perror(msg);
    exit(EXIT_FAILURE);
}

static void read_block(int fd, uint32_t block_no, void *buf) {
    if (lseek(fd, block_no * BLOCK_SIZE, SEEK_SET) < 0) {
        die("lseek");
    }
    if (read(fd, buf, BLOCK_SIZE) != BLOCK_SIZE) {
        die("read");
    }
}

static void write_block(int fd, uint32_t block_no, const void *buf) {
    if (lseek(fd, block_no * BLOCK_SIZE, SEEK_SET) < 0) {
        die("lseek");
    }
    if (write(fd, buf, BLOCK_SIZE) != BLOCK_SIZE) {
        die("write");
    }
}

static void read_journal_header(int fd, struct journal_header *jh) {
    if (lseek(fd, JOURNAL_BLOCK_IDX * BLOCK_SIZE, SEEK_SET) < 0) {
        die("lseek");
    }
    if (read(fd, jh, sizeof(struct journal_header)) != sizeof(struct journal_header)) {
        die("read journal header");
    }
}

static void write_journal_header(int fd, const struct journal_header *jh) {
    if (lseek(fd, JOURNAL_BLOCK_IDX * BLOCK_SIZE, SEEK_SET) < 0) {
        die("lseek");
    }
    if (write(fd, jh, sizeof(struct journal_header)) != sizeof(struct journal_header)) {
        die("write journal header");
    }
}

static int get_bitmap_bit(const uint8_t *bitmap, uint32_t index) {
    return (bitmap[index / 8] & (1U << (index % 8))) != 0;
}

static void set_bitmap_bit(uint8_t *bitmap, uint32_t index) {
    bitmap[index / 8] |= (1U << (index % 8));
}

static uint32_t find_free_inode(const uint8_t *inode_bitmap, uint32_t max_inodes) {
    for (uint32_t i = 0; i < max_inodes; i++) {
        if (!get_bitmap_bit(inode_bitmap, i)) {
            return i;
        }
    }
    return (uint32_t)-1;
}

static int journal_append_data(int fd, struct journal_header *jh, uint32_t block_no, const void *block_data) {
    uint32_t rec_size = sizeof(struct rec_header) + sizeof(uint32_t) + BLOCK_SIZE;
    
    if (jh->nbytes_used + rec_size > JOURNAL_BLOCKS * BLOCK_SIZE) {
        fprintf(stderr, "Journal full! Run install first.\n");
        return -1;
    }
    
    struct rec_header rec_hdr;
    rec_hdr.type = REC_DATA;
    rec_hdr.size = (uint16_t)rec_size;
    
    off_t offset = JOURNAL_BLOCK_IDX * BLOCK_SIZE + jh->nbytes_used;
    if (lseek(fd, offset, SEEK_SET) < 0) {
        die("lseek");
    }
    

    if (write(fd, &rec_hdr, sizeof(rec_hdr)) != sizeof(rec_hdr)) {
        die("write");
    }
    

    if (write(fd, &block_no, sizeof(block_no)) != sizeof(block_no)) {
        die("write");
    }
    

    if (write(fd, block_data, BLOCK_SIZE) != BLOCK_SIZE) {
        die("write");
    }
    
    jh->nbytes_used += rec_size;
    return 0;
}

static int journal_append_commit(int fd, struct journal_header *jh) {
    uint32_t rec_size = sizeof(struct rec_header);
    
    if (jh->nbytes_used + rec_size > JOURNAL_BLOCKS * BLOCK_SIZE) {
        fprintf(stderr, "Journal full! Run install first.\n");
        return -1;
    }
    
    struct rec_header rec_hdr;
    rec_hdr.type = REC_COMMIT;
    rec_hdr.size = (uint16_t)rec_size;
    
    off_t offset = JOURNAL_BLOCK_IDX * BLOCK_SIZE + jh->nbytes_used;
    if (lseek(fd, offset, SEEK_SET) < 0) {
        die("lseek");
    }
    if (write(fd, &rec_hdr, rec_size) != (ssize_t)rec_size) {
        die("write");
    }
    
    jh->nbytes_used += rec_size;
    
    write_journal_header(fd, jh);
    
    return 0;
}

static void cmd_create(const char *filename) {
    int fd = open(DEFAULT_IMAGE, O_RDWR);
    if (fd < 0) {
        die("open");
    }
    
    struct superblock sb;
    read_block(fd, 0, &sb);
    
    if (sb.magic != FS_MAGIC) {
        fprintf(stderr, "Invalid filesystem magic\n");
        close(fd);
        exit(EXIT_FAILURE);
    }
    

    struct journal_header jh;
    read_journal_header(fd, &jh);
    

    if (jh.magic != JOURNAL_MAGIC) {
        jh.magic = JOURNAL_MAGIC;
        jh.nbytes_used = sizeof(struct journal_header);
        write_journal_header(fd, &jh);
    }
    

    uint8_t inode_bitmap[BLOCK_SIZE];
    uint8_t data_bitmap[BLOCK_SIZE];
    read_block(fd, INODE_BMAP_IDX, inode_bitmap);
    read_block(fd, DATA_BMAP_IDX, data_bitmap);
    

    uint32_t new_inode_idx = find_free_inode(inode_bitmap, sb.inode_count);
    if (new_inode_idx == (uint32_t)-1) {
        fprintf(stderr, "No free inodes\n");
        close(fd);
        exit(EXIT_FAILURE);
    }
    

    uint8_t root_inode_block[BLOCK_SIZE];
    read_block(fd, INODE_START_IDX, root_inode_block);
    struct inode *root_inode = (struct inode *)root_inode_block;
    
    if (root_inode->type != INODE_TYPE_DIR) {
        fprintf(stderr, "Root inode is not a directory\n");
        close(fd);
        exit(EXIT_FAILURE);
    }
    

    uint32_t root_dir_block = root_inode->direct[0];
    uint8_t root_data[BLOCK_SIZE];
    read_block(fd, root_dir_block, root_data);
    
    struct dirent *dirents = (struct dirent *)root_data;
    int free_slot = -1;
    

    for (int i = 2; i < (int)(BLOCK_SIZE / sizeof(struct dirent)); i++) {
        if (dirents[i].inode == 0 && free_slot == -1) {
            free_slot = i;
        }
        if (dirents[i].inode != 0 && strcmp(dirents[i].name, filename) == 0) {
            fprintf(stderr, "File '%s' already exists\n", filename);
            close(fd);
            exit(EXIT_FAILURE);
        }
    }
    
    if (free_slot == -1) {
        fprintf(stderr, "Root directory full\n");
        close(fd);
        exit(EXIT_FAILURE);
    }
    

    set_bitmap_bit(inode_bitmap, new_inode_idx);
    

    dirents[free_slot].inode = new_inode_idx;
    strncpy(dirents[free_slot].name, filename, NAME_LEN - 1);
    dirents[free_slot].name[NAME_LEN - 1] = '\0';
    

    root_inode->size += sizeof(struct dirent);
    root_inode->mtime = (uint32_t)time(NULL);
    

    uint32_t inode_block_idx = INODE_START_IDX + (new_inode_idx * INODE_SIZE) / BLOCK_SIZE;
    uint32_t inode_offset = (new_inode_idx * INODE_SIZE) % BLOCK_SIZE;
    

    if (inode_block_idx == INODE_START_IDX) {

        struct inode *new_inode = (struct inode *)(root_inode_block + inode_offset);
        memset(new_inode, 0, sizeof(struct inode));
        new_inode->type = INODE_TYPE_FILE;
        new_inode->links = 1;
        new_inode->size = 0;
        new_inode->ctime = (uint32_t)time(NULL);
        new_inode->mtime = (uint32_t)time(NULL);
        

        if (journal_append_data(fd, &jh, INODE_BMAP_IDX, inode_bitmap) < 0) {
            close(fd);
            exit(EXIT_FAILURE);
        }
        

        if (journal_append_data(fd, &jh, INODE_START_IDX, root_inode_block) < 0) {
            close(fd);
            exit(EXIT_FAILURE);
        }
    } else {

        uint8_t new_inode_block[BLOCK_SIZE];
        read_block(fd, inode_block_idx, new_inode_block);
        
        struct inode *new_inode = (struct inode *)(new_inode_block + inode_offset);
        memset(new_inode, 0, sizeof(struct inode));
        new_inode->type = INODE_TYPE_FILE;
        new_inode->links = 1;
        new_inode->size = 0;
        new_inode->ctime = (uint32_t)time(NULL);
        new_inode->mtime = (uint32_t)time(NULL);
        

        if (journal_append_data(fd, &jh, INODE_BMAP_IDX, inode_bitmap) < 0) {
            close(fd);
            exit(EXIT_FAILURE);
        }
        

        if (journal_append_data(fd, &jh, inode_block_idx, new_inode_block) < 0) {
            close(fd);
            exit(EXIT_FAILURE);
        }
        

        if (journal_append_data(fd, &jh, INODE_START_IDX, root_inode_block) < 0) {
            close(fd);
            exit(EXIT_FAILURE);
        }
    }
    

    if (journal_append_data(fd, &jh, root_dir_block, root_data) < 0) {
        close(fd);
        exit(EXIT_FAILURE);
    }
    

    if (journal_append_commit(fd, &jh) < 0) {
        close(fd);
        exit(EXIT_FAILURE);
    }
    
    close(fd);
    printf("Logged creation of '%s' to journal.\n", filename);
}

static void cmd_install(void) {
    int fd = open(DEFAULT_IMAGE, O_RDWR);
    if (fd < 0) {
        die("open");
    }
    

    struct journal_header jh;
    read_journal_header(fd, &jh);
    
    if (jh.magic != JOURNAL_MAGIC) {
        printf("Journal is empty or uninitialized.\n");
        close(fd);
        return;
    }
    

    typedef struct {
        uint32_t block_no;
        uint8_t block_data[BLOCK_SIZE];
    } pending_write;
    
    pending_write *writes = malloc(sizeof(pending_write) * 100);
    if (!writes) {
        die("malloc");
    }
    
    uint32_t offset = sizeof(struct journal_header);
    int txn_count = 0;
    int write_count = 0;
    
    while (offset < jh.nbytes_used) {

        struct rec_header rec_hdr;
        if (lseek(fd, JOURNAL_BLOCK_IDX * BLOCK_SIZE + offset, SEEK_SET) < 0) {
            die("lseek");
        }
        
        ssize_t bytes_read = read(fd, &rec_hdr, sizeof(rec_hdr));
        if (bytes_read != sizeof(rec_hdr)) {
            break;
        }
        
        if (rec_hdr.type == REC_COMMIT) {

            for (int i = 0; i < write_count; i++) {
                write_block(fd, writes[i].block_no, writes[i].block_data);
            }
            txn_count++;
            write_count = 0;  
            offset += rec_hdr.size;
            
        } else if (rec_hdr.type == REC_DATA) {

            uint32_t block_no;
            if (read(fd, &block_no, sizeof(block_no)) != sizeof(block_no)) {
                break;
            }
            

            uint8_t block_data[BLOCK_SIZE];
            if (read(fd, block_data, BLOCK_SIZE) != BLOCK_SIZE) {
                break;
            }
            

            if (write_count < 100) {
                writes[write_count].block_no = block_no;
                memcpy(writes[write_count].block_data, block_data, BLOCK_SIZE);
                write_count++;
            }
            
            offset += rec_hdr.size;
            
        } else {

            break;
        }
    }
    

    if (write_count > 0) {
        printf("Warning: %d uncommitted DATA records discarded.\n", write_count);
    }
    
    free(writes);
    

    memset(&jh, 0, sizeof(jh));
    jh.magic = JOURNAL_MAGIC;
    jh.nbytes_used = sizeof(struct journal_header);
    write_journal_header(fd, &jh);
    
    close(fd);
    printf("Installed %d committed transaction%s from journal.\n", 
           txn_count, txn_count == 1 ? "" : "s");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <create|install> [filename]\n", argv[0]);
        return EXIT_FAILURE;
    }
    
    if (strcmp(argv[1], "create") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Usage: %s create <filename>\n", argv[0]);
            return EXIT_FAILURE;
        }
        cmd_create(argv[2]);
    } else if (strcmp(argv[1], "install") == 0) {
        cmd_install();
    } else {
        fprintf(stderr, "Unknown command: %s\n", argv[1]);
        return EXIT_FAILURE;
    }
    
    return EXIT_SUCCESS;
}
