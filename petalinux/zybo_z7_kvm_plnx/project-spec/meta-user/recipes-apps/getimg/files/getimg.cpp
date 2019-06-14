#include <iostream>
#include <string>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <vector>
#include <cstring>

using namespace std;

static const uint64_t kBaseAddr = 0x40000000;
static const uint64_t kBaseImgAddr = kBaseAddr + 0xC;
static const uint64_t kBaseUnfreezeAddr = kBaseAddr + 0x4;
static const uint64_t kImageOffset = 0x10;
static const uint32_t kPageSize = sysconf(_SC_PAGESIZE);
static const uint32_t kPageMask = ~(kPageSize - 1);
static const uint64_t kMaxBuffSize = 4096ull * 1024ull * 1024ull;

inline uint64_t getFreezeAddr(int imgNr)
{
    return kBaseAddr + imgNr * kImageOffset;
}

inline uint64_t getUnfreezeAddr(int imgNr)
{
    return kBaseUnfreezeAddr + imgNr * kImageOffset;
}

inline uint64_t getImageAddr(int imgNr)
{
    return kBaseImgAddr + imgNr * kImageOffset;
}

class Descriptor
{
public:
    Descriptor(const std::string & path, int flags)
    {
        int m_fd = open(path.c_str(), flags);
        if (m_fd < 1) {
            std::cout << "File open failed: " << errno << std::endl;
        }
    }

    bool isOpen ()
    {
        return m_fd > 0;
    }

    int getFd()
    {
        return m_fd;
    }

    Descriptor(const Descriptor&) = delete;
    Descriptor(const Descriptor&&) = delete;

    ~Descriptor()
    {
        close(m_fd);
    }

private:
    int m_fd;
};


/*TODO: Should pass FD to MemoryAccess also it should  be singleton*/
class MemoryAccess
{
public:
    MemoryAccess(uint64_t size, int fd, uint64_t pageAddr, int flags) :
        m_memSize { size },
        m_flags { flags },
        m_fd { fd }
    {
        m_pageAddr = pageAddr & kPageMask;
        m_mappedMem = mmap(NULL, m_memSize, m_flags, MAP_SHARED, m_fd, m_pageAddr);
        if (m_mappedMem == MAP_FAILED) {
            std::cout << "Could not map the memory, errno " << errno << std::endl;
        }
    }

    bool isMemoryMapped ()
    {
        return m_mappedMem != MAP_FAILED;
    }

    uint64_t peek(uint64_t addr)
    {
        if (isMemoryMapped())
        {
            uint64_t pageAddr = (addr & kPageMask);
            uint64_t pageOffset = addr - pageAddr;
            return *((uint32_t *)(m_mappedMem) + pageOffset);
        }
        return 0;
    }

    void poke(uint64_t addr, uint32_t val)
    {
        if (isMemoryMapped())
        {
            /*TODO: Needs some clarifications*/
            uint64_t pageAddr = (addr & kPageMask);
            uint64_t pageOffset = addr - pageAddr;
            *((uint32_t *)(m_mappedMem) + pageOffset) = val;
        }
    }

    uint32_t readData(uint64_t addr, uint64_t size, uint8_t * buffer)
    {
        if (buffer == nullptr) {
            std::cout << " null buffer \n";
            return 0;
        }

        if (!isMemoryMapped()) {
            std::cout << "Memory is not mapped, errno " << errno << "\n";
            return 0;
        }

        uint32_t length = *(uint32_t*) m_mappedMem;
        auto extraBytes = addr - m_pageAddr;
        memcpy(buffer, (char *)m_mappedMem + extraBytes + m_dataOffset, length);
        return length;
    }

    ~MemoryAccess()
    {
        munmap(m_mappedMem, m_memSize);
    }

private:
    void *m_mappedMem;
    uint64_t m_memSize;
    uint64_t m_pageAddr;
    static const uint64_t m_dataOffset { 0x80 };
    int m_flags;
    int m_fd;
};

int getImageNr()
{
    std::string queryString { "" };

    auto str = getenv("QUERY_STRING");
    if (str != nullptr) {
        queryString = str;
    } else {
        std::cout << "Could not parse imageNr, NULL str" << std::endl;
        return -1;
    }

    //std::string queryString { "ch=1&t=155000000&ext=.jpeg" };
    if (queryString != "") {
        static const std::string startString { "ch= "};
        auto start = queryString.find("=") + 1;
        auto end = queryString.find("&");

        if (end <= start ) {
            std::cout << " Invalid String " << queryString << std::endl;
            return -1;
        }

        auto size = end - start;
        std::string imgNrStr = queryString.substr(start, size);

        int imgNr = -1;
        try {
            imgNr = stoi(imgNrStr);
        } catch (std::exception & ex) {
            std::cout << " Could not get Img nr From " << imgNrStr << " ex " << ex.what() << std::endl;
            return -1;
        }
        return imgNr;
    }


    std::cout << "Could not parse imageNr " << std::endl;
    return -1;
}

int main(int argc, char** argv)
{
#if 0
    int imgNr = getImageNr();
    if (imgNr < 0) {
        abort();
    }
    std::cout << " imgNr " << imgNr << std::endl;
#else
    int imgNr = 1;
#endif
    static const std::string filePath  { "/dev/mem" };
    static const int fileFlags = O_RDWR;

    Descriptor desc { filePath, fileFlags };

    MemoryAccess controlMem { kPageSize, desc.getFd(),  kBaseAddr, PROT_READ | PROT_WRITE };
    controlMem.poke(getFreezeAddr(imgNr), 0);
    auto imageAddr = controlMem.peek(getImageAddr(imgNr));

    MemoryAccess dataMem { kMaxBuffSize, desc.getFd(),  imageAddr, PROT_READ };

    /*TODO: do I need more than 4MB?*/
    std::vector<uint8_t> buffer(kPageSize + kMaxBuffSize, 0);
    auto length = dataMem.readData(imageAddr, kMaxBuffSize, buffer.data());

    std::cout << "Content-type: image/jpeg\n\n"
              << std::string(buffer.begin(), buffer.begin() + length)
              << std::endl;
    controlMem.poke(getUnfreezeAddr(imgNr), 0);

    return 0;
}


#if 0

static const std::string supportedOptions {""};
struct options
{
  int place_holder;
};

options getOptions(int argc, char** argv)
{
    if (argc < 2) {
        std::cout << " Not enough argumetnts \n";
        exit(1);
    }

    int opt;
    while ( (opt = getopt(argc, argv, supportedOptions.c_str())) != -1 ) {
        switch ( opt ) {
        case 'a':
            break;
        case '?':  // unknown option...
            cerr << "Unknown option: '" << char(opt) << "'!" << endl;
            break;
        }
    }

    return {};
}

uint64_t peek(int fd, uint64_t addr)
{
    void *ptr;
    unsigned pageAddr, pageOffset;
    pageAddr = (addr & kPageMask);
    pageOffset = addr-pageAddr;

    ptr = mmap(NULL, kPageSize, PROT_READ, MAP_SHARED, fd, pageAddr);
    if (ptr == MAP_FAILED) {
        perror("mmap failed: ");
        exit(1);
    }
    munmap(ptr, kPageSize);
    return *((uint32_t *)(ptr) + pageOffset);
}

uint64_t poke(int fd, uint64_t addr, uint32_t val)
{
    void *ptr;
    unsigned pageAddr, pageOffset;

    pageAddr=(addr & kPageMask);
    pageOffset=addr-pageAddr;

    ptr = mmap(NULL, kPageSize, PROT_READ|PROT_WRITE, MAP_SHARED, fd, pageAddr);
    close(fd);
    if (ptr == MAP_FAILED) {
        perror("mmap failed: ");
        exit(1);
    }
    munmap(ptr, kPageSize);
    return *((uint32_t *)(ptr) + pageOffset) = val;
}



uint32_t readData(int fd, uint64_t addr, uint64_t size, uint8_t * buffer)
{
    if (buffer == nullptr) {
        std::cout << " null buffer \n";
        return -1;
    }

    off_t mapBase = addr & kPageMask;
    off_t extraBytes = addr - mapBase;

    auto mapping = mmap(NULL, size, PROT_READ, MAP_SHARED, fd, mapBase);
    close(fd);

    if (mapping == MAP_FAILED) {
        perror("Could not map memory");
        exit(1);
    }

    uint32_t length = *(uint32_t*) mapping;

    static const uint32_t dataOffset = 0x80;
    memcpy(buffer, (char *)mapping + extraBytes + dataOffset, length);
    munmap(mapping, size);
    return length;
}

#endif
