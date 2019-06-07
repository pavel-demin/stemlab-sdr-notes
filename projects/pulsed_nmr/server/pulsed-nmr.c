#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

int main(int argc, char *argv[])
{
  int fd, sock_server, sock_client;
  void *cfg, *sts;
  volatile uint32_t *tx_data, *rx_freq, *tx_freq;
  volatile uint16_t *rx_rate, *rx_cntr, *tx_cntr;
  volatile int16_t *tx_level;
  volatile uint8_t *rx_rst, *tx_rst;
  volatile uint64_t *rx_data;
  struct sockaddr_in addr;
  uint32_t command, value;
  uint64_t buffer[8192];
  int i, j, size, yes = 1;

  if((fd = open("/dev/mem", O_RDWR)) < 0)
  {
    perror("open");
    return EXIT_FAILURE;
  }

  sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40000000);
  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40001000);
  rx_data = mmap(NULL, 16*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40010000);
  tx_data = mmap(NULL, 2*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40002000);

  rx_rst = ((uint8_t *)(cfg + 0));
  rx_freq = ((uint32_t *)(cfg + 4));
  rx_rate = ((uint16_t *)(cfg + 8));
  rx_cntr = ((uint16_t *)(sts + 12));

  tx_rst = ((uint8_t *)(cfg + 1));
  tx_freq = ((uint32_t *)(cfg + 12));
  tx_level = ((int16_t *)(cfg + 16));
  tx_cntr = ((uint16_t *)(sts + 14));

  *rx_rst |= 1;
  *rx_rst &= ~2;
  *tx_rst |= 1;

  /* set default rx phase increment */
  *rx_freq = (uint32_t)floor(19000000 / 122.88e6 * (1<<30) + 0.5);
  /* set default rx sample rate */
  *rx_rate = 256;

  /* set default tx phase increment */
  *tx_freq = (uint32_t)floor(19000000 / 122.88e6 * (1<<30) + 0.5);
  /* set default tx level */
  *tx_level = 16382;

  if((sock_server = socket(AF_INET, SOCK_STREAM, 0)) < 0)
  {
    perror("socket");
    return EXIT_FAILURE;
  }

  setsockopt(sock_server, SOL_SOCKET, SO_REUSEADDR, (void *)&yes , sizeof(yes));

  /* setup listening address */
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = htons(1001);

  if(bind(sock_server, (struct sockaddr *)&addr, sizeof(addr)) < 0)
  {
    perror("bind");
    return EXIT_FAILURE;
  }

  listen(sock_server, 1024);

  while(1)
  {
    if((sock_client = accept(sock_server, NULL, NULL)) < 0)
    {
      perror("accept");
      return EXIT_FAILURE;
    }

    while(1)
    {
      if(recv(sock_client, (char *)&command, 4, MSG_WAITALL) <= 0) break;
      value = command & 0xfffffff;
      switch(command >> 28)
      {
        case 0:
          /* set rx and tx phase increment */
          if(value < 0 || value > 60000000) continue;
          *rx_freq = (uint32_t)floor(value / 122.88e6 * (1<<30) + 0.5);
          *tx_freq = (uint32_t)floor(value / 122.88e6 * (1<<30) + 0.5);
          break;
        case 1:
          /* set rx sample rate */
          switch(command & 7)
          {
            case 0:
              *rx_rate = 2048;
              break;
            case 1:
              *rx_rate = 1024;
              break;
            case 2:
              *rx_rate = 512;
              bre3k;
            case 3:
              *rx_rate = 256;
              break;
            case 4:
              *rx_rate = 128;
              break;
            case 5:
              *rx_rate = 64;
              break;
            case 6:
              *rx_rate = 32;
              break;
            case 7:
              *rx_rate = 16;
              break;
          }
          break;
        case 2:
          /* set A width */
          *tx_rst |= 1; *tx_rst &= ~1;

          *tx_data = 0;
          *tx_data = 100-2;
          *tx_data = 50-1;
          *tx_data = 0;

          *tx_data = (uint32_t)floor(0.25 * (1<<30) + 0.5);;
          *tx_data = 150-2;
          *tx_data = 75-1;
          *tx_data = 0;

          *tx_data = (uint32_t)floor(0.5 * (1<<30) + 0.5);;
          *tx_data = 100-2;
          *tx_data = 50-1;
          *tx_data = 0;

          break;
        case 3:
          /* fire */
          *rx_rst |= 1; *rx_rst &= ~1;
          *rx_rst &= ~2; *rx_rst |= 2;
          /* transfer 5 * 8192 = 40960 samples */
          for(i = 0; i < 5; ++i)
          {
            while(*rx_cntr < 16384) usleep(500);
            for(j = 0; j < 8192; ++j) buffer[j] = *rx_data;
            send(sock_client, buffer, 65536, MSG_NOSIGNAL);
          }
          *rx_rst |= 1;
          *rx_rst &= ~2;
          *tx_rst |= 1;
          break;
      }
    }

    close(sock_client);
  }

  close(sock_server);

  return EXIT_SUCCESS;
}
