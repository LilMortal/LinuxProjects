/*
 * simplechar.c - A simple character device driver for Linux
 * 
 * This kernel module implements a basic character device that demonstrates
 * fundamental kernel programming concepts including device registration,
 * file operations, memory management, and kernel logging.
 *
 * Author: Your Name
 * License: MIT
 * Version: 1.0
 */

#include <linux/init.h>          /* Macros used to mark functions */
#include <linux/module.h>        /* Core header for loading LKMs */
#include <linux/device.h>        /* Header to support the kernel Driver Model */
#include <linux/fs.h>            /* Header for Linux file system support */
#include <linux/cdev.h>          /* Character device structure */
#include <linux/uaccess.h>       /* Required for copy_to_user/copy_from_user */
#include <linux/slab.h>          /* Required for kmalloc/kfree */
#include <linux/mutex.h>         /* Mutex support for concurrency */
#include <linux/proc_fs.h>       /* Proc filesystem support */
#include <linux/seq_file.h>      /* Sequential file operations */

#define DEVICE_NAME "simplechar"  /* Device name as it appears in /dev */
#define CLASS_NAME  "simple"      /* Device class name */
#define BUFFER_SIZE_DEFAULT 1024  /* Default buffer size */
#define BUFFER_SIZE_MAX 4096      /* Maximum buffer size */

/* Module information */
MODULE_LICENSE("MIT");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("A simple character device driver");
MODULE_VERSION("1.0");

/* Module parameters */
static int buffer_size = BUFFER_SIZE_DEFAULT;
static int debug_level = 1;
static char *device_name = DEVICE_NAME;

module_param(buffer_size, int, S_IRUGO);
MODULE_PARM_DESC(buffer_size, "Size of the internal buffer (max 4096)");

module_param(debug_level, int, S_IRUGO);
MODULE_PARM_DESC(debug_level, "Debug verbosity level (0-3)");

module_param(device_name, charp, S_IRUGO);
MODULE_PARM_DESC(device_name, "Device name (default: simplechar)");

/* Device structure */
struct simplechar_dev {
    char *buffer;           /* Internal data buffer */
    size_t buffer_len;      /* Current data length */
    size_t buffer_size;     /* Total buffer size */
    struct mutex mutex;     /* Mutex for thread safety */
    struct cdev cdev;       /* Character device structure */
    atomic_t open_count;    /* Number of times device is open */
    unsigned long read_count;  /* Statistics: read operations */
    unsigned long write_count; /* Statistics: write operations */
};

/* Global variables */
static struct simplechar_dev *simple_dev;
static int major_number;
static struct class *simple_class = NULL;
static struct device *simple_device = NULL;
static struct proc_dir_entry *proc_entry = NULL;

/* Debug macros */
#define DEBUG_PRINT(level, fmt, args...) \
    do { \
        if (debug_level >= level) { \
            printk(KERN_DEBUG "simplechar: " fmt, ##args); \
        } \
    } while (0)

#define INFO_PRINT(fmt, args...) \
    printk(KERN_INFO "simplechar: " fmt, ##args)

#define WARN_PRINT(fmt, args...) \
    printk(KERN_WARNING "simplechar: " fmt, ##args)

#define ERR_PRINT(fmt, args...) \
    printk(KERN_ERR "simplechar: " fmt, ##args)

/* Function prototypes */
static int device_open(struct inode *, struct file *);
static int device_release(struct inode *, struct file *);
static ssize_t device_read(struct file *, char __user *, size_t, loff_t *);
static ssize_t device_write(struct file *, const char __user *, size_t, loff_t *);
static long device_ioctl(struct file *, unsigned int, unsigned long);

/* File operations structure */
static struct file_operations fops = {
    .owner = THIS_MODULE,
    .open = device_open,
    .release = device_release,
    .read = device_read,
    .write = device_write,
    .unlocked_ioctl = device_ioctl,
};

/* Proc filesystem operations */
static int simplechar_proc_show(struct seq_file *m, void *v)
{
    seq_printf(m, "SimpleChar Module Status:\n");
    seq_printf(m, "  Major Number: %d\n", major_number);
    seq_printf(m, "  Buffer Size: %zu bytes\n", simple_dev->buffer_size);
    seq_printf(m, "  Current Data Length: %zu bytes\n", simple_dev->buffer_len);
    seq_printf(m, "  Open Count: %d\n", atomic_read(&simple_dev->open_count));
    seq_printf(m, "  Read Operations: %lu\n", simple_dev->read_count);
    seq_printf(m, "  Write Operations: %lu\n", simple_dev->write_count);
    seq_printf(m, "  Debug Level: %d\n", debug_level);
    return 0;
}

static int simplechar_proc_open(struct inode *inode, struct file *file)
{
    return single_open(file, simplechar_proc_show, NULL);
}

static const struct proc_ops simplechar_proc_ops = {
    .proc_open = simplechar_proc_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = single_release,
};

/*
 * Device open function
 * Called when a process opens the device file
 */
static int device_open(struct inode *inodep, struct file *filep)
{
    DEBUG_PRINT(2, "Device open attempt\n");
    
    /* Increment open count atomically */
    atomic_inc(&simple_dev->open_count);
    
    DEBUG_PRINT(2, "Device opened successfully (open count: %d)\n",
                atomic_read(&simple_dev->open_count));
    
    return 0;
}

/*
 * Device release function
 * Called when a process closes the device file
 */
static int device_release(struct inode *inodep, struct file *filep)
{
    DEBUG_PRINT(2, "Device release attempt\n");
    
    /* Decrement open count atomically */
    atomic_dec(&simple_dev->open_count);
    
    DEBUG_PRINT(2, "Device closed (open count: %d)\n",
                atomic_read(&simple_dev->open_count));
    
    INFO_PRINT("Device closed, total reads: %lu, writes: %lu\n",
               simple_dev->read_count, simple_dev->write_count);
    
    return 0;
}

/*
 * Device read function
 * Called when a process reads from the device file
 */
static ssize_t device_read(struct file *filep, char __user *buffer, 
                          size_t len, loff_t *offset)
{
    int bytes_read = 0;
    int ret;
    
    DEBUG_PRINT(3, "Read request: len=%zu, offset=%lld\n", len, *offset);
    
    /* Acquire mutex to prevent concurrent access */
    if (mutex_lock_interruptible(&simple_dev->mutex)) {
        return -ERESTARTSYS;
    }
    
    /* Check if we're at end of data */
    if (*offset >= simple_dev->buffer_len) {
        DEBUG_PRINT(3, "Read at EOF\n");
        goto out;
    }
    
    /* Calculate how many bytes to read */
    bytes_read = min(len, simple_dev->buffer_len - *offset);
    
    /* Copy data to user space */
    ret = copy_to_user(buffer, simple_dev->buffer + *offset, bytes_read);
    if (ret) {
        ERR_PRINT("Failed to copy %d bytes to user space\n", ret);
        bytes_read = -EFAULT;
        goto out;
    }
    
    /* Update offset and statistics */
    *offset += bytes_read;
    simple_dev->read_count++;
    
    DEBUG_PRINT(2, "Read %d bytes from device\n", bytes_read);

out:
    mutex_unlock(&simple_dev->mutex);
    return bytes_read;
}

/*
 * Device write function
 * Called when a process writes to the device file
 */
static ssize_t device_write(struct file *filep, const char __user *buffer,
                           size_t len, loff_t *offset)
{
    int bytes_written = 0;
    int ret;
    
    DEBUG_PRINT(3, "Write request: len=%zu, offset=%lld\n", len, *offset);
    
    /* Acquire mutex to prevent concurrent access */
    if (mutex_lock_interruptible(&simple_dev->mutex)) {
        return -ERESTARTSYS;
    }
    
    /* Check if write would exceed buffer size */
    if (*offset >= simple_dev->buffer_size) {
        WARN_PRINT("Write attempt beyond buffer size\n");
        bytes_written = -ENOSPC;
        goto out;
    }
    
    /* Calculate how many bytes to write */
    bytes_written = min(len, simple_dev->buffer_size - *offset);
    
    /* Copy data from user space */
    ret = copy_from_user(simple_dev->buffer + *offset, buffer, bytes_written);
    if (ret) {
        ERR_PRINT("Failed to copy %d bytes from user space\n", ret);
        bytes_written = -EFAULT;
        goto out;
    }
    
    /* Update offset, data length, and statistics */
    *offset += bytes_written;
    if (*offset > simple_dev->buffer_len) {
        simple_dev->buffer_len = *offset;
    }
    simple_dev->write_count++;
    
    DEBUG_PRINT(2, "Wrote %d bytes to device\n", bytes_written);

out:
    mutex_unlock(&simple_dev->mutex);
    return bytes_written;
}

/*
 * Device ioctl function
 * Handles device-specific control operations
 */
static long device_ioctl(struct file *filep, unsigned int cmd, unsigned long arg)
{
    DEBUG_PRINT(3, "IOCTL request: cmd=0x%x, arg=%lu\n", cmd, arg);
    
    /* For now, just return success for any ioctl call */
    /* In a real driver, you would handle specific commands here */
    
    return 0;
}

/*
 * Module initialization function
 * Called when the module is loaded
 */
static int __init simplechar_init(void)
{
    int ret;
    dev_t dev_num;
    
    INFO_PRINT("Initializing SimpleChar module\n");
    
    /* Validate parameters */
    if (buffer_size <= 0 || buffer_size > BUFFER_SIZE_MAX) {
        ERR_PRINT("Invalid buffer size: %d (max: %d)\n", 
                  buffer_size, BUFFER_SIZE_MAX);
        return -EINVAL;
    }
    
    if (debug_level < 0 || debug_level > 3) {
        WARN_PRINT("Debug level out of range, setting to 1\n");
        debug_level = 1;
    }
    
    /* Allocate device structure */
    simple_dev = kzalloc(sizeof(struct simplechar_dev), GFP_KERNEL);
    if (!simple_dev) {
        ERR_PRINT("Failed to allocate device structure\n");
        return -ENOMEM;
    }
    
    /* Allocate buffer */
    simple_dev->buffer = kzalloc(buffer_size, GFP_KERNEL);
    if (!simple_dev->buffer) {
        ERR_PRINT("Failed to allocate buffer\n");
        ret = -ENOMEM;
        goto fail_buffer;
    }
    
    /* Initialize device structure */
    simple_dev->buffer_size = buffer_size;
    simple_dev->buffer_len = 0;
    mutex_init(&simple_dev->mutex);
    atomic_set(&simple_dev->open_count, 0);
    simple_dev->read_count = 0;
    simple_dev->write_count = 0;
    
    /* Allocate device number */
    ret = alloc_chrdev_region(&dev_num, 0, 1, device_name);
    if (ret < 0) {
        ERR_PRINT("Failed to allocate device number\n");
        goto fail_chrdev;
    }
    major_number = MAJOR(dev_num);
    
    /* Initialize character device */
    cdev_init(&simple_dev->cdev, &fops);
    simple_dev->cdev.owner = THIS_MODULE;
    
    /* Add character device to system */
    ret = cdev_add(&simple_dev->cdev, dev_num, 1);
    if (ret < 0) {
        ERR_PRINT("Failed to add character device\n");
        goto fail_cdev;
    }
    
    /* Create device class */
    simple_class = class_create(THIS_MODULE, CLASS_NAME);
    if (IS_ERR(simple_class)) {
        ERR_PRINT("Failed to create device class\n");
        ret = PTR_ERR(simple_class);
        goto fail_class;
    }
    
    /* Create device file */
    simple_device = device_create(simple_class, NULL, dev_num, NULL, device_name);
    if (IS_ERR(simple_device)) {
        ERR_PRINT("Failed to create device file\n");
        ret = PTR_ERR(simple_device);
        goto fail_device;
    }
    
    /* Create proc entry */
    proc_entry = proc_create("simplechar", 0644, NULL, &simplechar_proc_ops);
    if (!proc_entry) {
        WARN_PRINT("Failed to create proc entry\n");
        /* Not a fatal error, continue without proc entry */
    }
    
    INFO_PRINT("SimpleChar module loaded successfully\n");
    INFO_PRINT("Buffer size: %d bytes\n", buffer_size);
    INFO_PRINT("Debug level: %d\n", debug_level);
    INFO_PRINT("Device major number: %d\n", major_number);
    INFO_PRINT("Device file: /dev/%s created\n", device_name);
    
    return 0;

fail_device:
    class_destroy(simple_class);
fail_class:
    cdev_del(&simple_dev->cdev);
fail_cdev:
    unregister_chrdev_region(MKDEV(major_number, 0), 1);
fail_chrdev:
    kfree(simple_dev->buffer);
fail_buffer:
    kfree(simple_dev);
    return ret;
}

/*
 * Module cleanup function
 * Called when the module is unloaded
 */
static void __exit simplechar_exit(void)
{
    INFO_PRINT("Cleaning up SimpleChar module\n");
    
    /* Remove proc entry */
    if (proc_entry) {
        proc_remove(proc_entry);
        DEBUG_PRINT(1, "Proc entry removed\n");
    }
    
    /* Remove device file */
    if (simple_device) {
        device_destroy(simple_class, MKDEV(major_number, 0));
        DEBUG_PRINT(1, "Device file removed\n");
    }
    
    /* Remove device class */
    if (simple_class) {
        class_destroy(simple_class);
        DEBUG_PRINT(1, "Device class removed\n");
    }
    
    /* Remove character device */
    if (simple_dev) {
        cdev_del(&simple_dev->cdev);
        DEBUG_PRINT(1, "Character device removed\n");
    }
    
    /* Unregister device number */
    unregister_chrdev_region(MKDEV(major_number, 0), 1);
    DEBUG_PRINT(1, "Device number unregistered\n");
    
    /* Free allocated memory */
    if (simple_dev) {
        if (simple_dev->buffer) {
            kfree(simple_dev->buffer);
        }
        kfree(simple_dev);
        DEBUG_PRINT(1, "Memory freed\n");
    }
    
    INFO_PRINT("SimpleChar module unloaded successfully\n");
}

/* Register module entry and exit points */
module_init(simplechar_init);
module_exit(simplechar_exit);