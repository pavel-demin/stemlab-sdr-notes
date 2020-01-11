#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <math.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define TCP_PORT 1001

int interrupted = 0;

void signal_handler(int sig)
{
  interrupted = 1;
}

int main ()
{
  int mmapfd, sockServer, sockClient;
  int position, limit, offset;
  volatile uint32_t *slcr, *axi_hp0;
  volatile void *cfg, *sts, *ram, *buf;
  struct sockaddr_in addr;
  uint32_t command, size;
  int32_t value;
  int yes = 1;

  if((mmapfd = open("/dev/mem", O_RDWR)) < 0)
  {
    perror("open");
    return 1;
  }

  slcr = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mmapfd, 0xF8000000);
  axi_hp0 = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mmapfd, 0xF8008000);
  sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mmapfd, 0x40000000);
  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mmapfd, 0x40001000);
  ram = mmap(NULL, 2048*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, mmapfd, 0x1E000000);
  buf = mmap(NULL, 2048*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED|MAP_ANONYMOUS, -1, 0);

  /* set HP0 bus width to 64 bits */
  slcr[2] = 0xDF0D;
  slcr[144] = 0;
  axi_hp0[0] &= ~1;
  axi_hp0[5] &= ~1;

  if((sockServer = socket(AF_INET, SOCK_STREAM, 0)) < 0)
  {
    perror("socket");
    return 1;
  }

  setsockopt(sockServer, SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));

  /* setup listening address */
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = htons(TCP_PORT);

  if(bind(sockServer, (struct sockaddr *)&addr, sizeof(addr)) < 0)
  {
    perror("bind");
    return 1;
  }

  listen(sockServer, 1024);

  while(!interrupted)
  {
    /* enter reset mode */
    *(uint8_t *)(cfg + 0) &= ~1;
    usleep(100);
    *(uint8_t *)(cfg + 0) &= ~2;
    /* set default sample rate */
    *(uint16_t *)(cfg + 2) = 10;
    /* set default phase increments */
    *(uint32_t *)(cfg + 4) = (uint32_t)floor(10000000 / 122.88e6 * (1<<30) + 0.5);
    *(uint32_t *)(cfg + 8) = (uint32_t)floor(10000000 / 122.88e6 * (1<<30) + 0.5);

    if((sockClient = accept(sockServer, NULL, NULL)) < 0)
    {
      perror("accept");
      return 1;
    }

    signal(SIGINT, signal_handler);

    /* enter normal operating mode */
    *(uint8_t *)(cfg + 0) |= 3;

    limit = 512*1024;

    while(!interrupted)
    {
      if(ioctl(sockClient, FIONREAD, &size) < 0) break;

      if(size >= 4)
      {
        if(recv(sockClient, (char *)&command, 4, MSG_WAITALL) < 0) break;
        value = command & 0xfffffff;
        switch(command >> 28)
        {
          case 0:
            /* set sample rate */
            if(value < 8 || value > 64) continue;
            *(uint16_t *)(cfg + 2) = value;
          case 1:
            /* set first phase increment */
            if(value < 0 || value > 61440000) continue;
            *((uint32_t *)(cfg + 4)) = (uint32_t)floor(value / 122.88e6 * (1<<30) + 0.5);
            break;
          case 2:
            /* set first phase increment */
            if(value < 0 || value > 61440000) continue;
            *((uint32_t *)(cfg + 8)) = (uint32_t)floor(value / 122.88e6 * (1<<30) + 0.5);
            break;
        }
      }

      /* read ram writer position */
      position = *(uint32_t *)(sts + 12);

      /* send 4 MB if ready, otherwise sleep 1 ms */
      if((limit > 0 && position > limit) || (limit == 0 && position < 512*1024))
      {
        offset = limit > 0 ? 0 : 4096*1024;
        limit = limit > 0 ? 0 : 512*1024;
        memcpy(buf + offset, ram + offset, 4096*1024);
        if(send(sockClient, buf + offset, 4096*1024, MSG_NOSIGNAL) < 0) break;
      }
      else
      {
        usleep(1000);
      }
    }

    signal(SIGINT, SIG_DFL);
    close(sockClient);
  }

  /* enter reset mode */
  *(uint8_t *)(cfg + 0) &= ~1;
  usleep(100);
  *(uint8_t *)(cfg + 0) &= ~2;

  close(sockServer);

  return 0;
}
