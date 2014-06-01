/*
Copyright 2005, 2006, 2007 Dennis van Weeren
Copyright 2008, 2009 Jakub Bednarski

This file is part of Minimig

Minimig is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Minimig is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// 2009-10-10   - any length (any multiple of 8 bytes) fpga core file support
// 2009-12-10   - changed command header id
// 2010-04-14   - changed command header id

//#include "AT91SAM7S256.h"
#include "stdio.h"
#include "string.h"
#include "hardware.h"
#include "fdd.h"

#include "fpga.h"

#define CMD_HDRID 0xAACA

extern char s[40];

// single byte serialization of FPGA configuration datastream
//void ShiftFpga(unsigned char data)
//{
//    AT91_REG *ppioa_codr = AT91C_PIOA_CODR;
//    AT91_REG *ppioa_sodr = AT91C_PIOA_SODR;
//
//    // bit 0
//    *ppioa_codr = DIN | CCLK;
//    if (data & 0x80)
//        *ppioa_sodr = DIN;
//    *ppioa_sodr = CCLK;
//
//    // bit 1
//    *ppioa_codr = DIN | CCLK;
//    if (data & 0x40)
//        *ppioa_sodr = DIN;
//    *ppioa_sodr = CCLK;
//
//    // bit 2
//    *ppioa_codr = DIN | CCLK;
//    if (data & 0x20)
//        *ppioa_sodr = DIN;
//    *ppioa_sodr = CCLK;
//
//    // bit 3
//    *ppioa_codr = DIN | CCLK;
//    if (data & 0x10)
//        *ppioa_sodr = DIN;
//    *ppioa_sodr = CCLK;
//
//    // bit 4
//    *ppioa_codr = DIN | CCLK;
//    if (data & 0x08)
//        *ppioa_sodr = DIN;
//    *ppioa_sodr = CCLK;
//
//    // bit 5
//    *ppioa_codr = DIN | CCLK;
//    if (data & 0x04)
//        *ppioa_sodr = DIN;
//    *ppioa_sodr = CCLK;
//
//    // bit 6
//    *ppioa_codr = DIN | CCLK;
//    if (data & 0x02)
//        *ppioa_sodr = DIN;
//    *ppioa_sodr = CCLK;
//
//    // bit 7
//    *ppioa_codr = DIN | CCLK;
//    if (data & 0x01)
//        *ppioa_sodr = DIN;
//    *ppioa_sodr = CCLK;
//
//}
//
//// FPGA configuration
//unsigned char ConfigureFpga(void)
//{
//    unsigned long  t;
//    unsigned long  n;
//    unsigned char *ptr;
//
//    // set outputs
//    *AT91C_PIOA_SODR = CCLK | DIN | PROG_B;
//    // enable outputs
//    *AT91C_PIOA_OER = CCLK | DIN | PROG_B;
//
//    // reset FGPA configuration sequence
//    // specs: PROG_B pulse min 0.3 us
//    t = 15;
//    while (--t)
//        *AT91C_PIOA_CODR = PROG_B;
//
//    *AT91C_PIOA_SODR = PROG_B;
//
//    // now wait for INIT to go high
//    // specs: max 2ms
//    t = 100000;
//    while (!(*AT91C_PIOA_PDSR & INIT_B))
//    {
//        if (--t == 0)
//        {
//            printf("FPGA init is NOT high!\r");
//            FatalError(3);
//        }
//    }
//
//    printf("FPGA init is high\r");
//
//    if (*AT91C_PIOA_PDSR & DONE)
//    {
//        printf("FPGA done is high before configuration!\r");
//        FatalError(3);
//    }
//
//    // open bitstream file
//    if (FileOpen(&file, "MINIMIG1BIN") == 0)
//    {
//        printf("No FPGA configuration file found!\r");
//        FatalError(4);
//    }
//
//    printf("FPGA bitstream file opened\r");
//    printf("[");
//
//    // send all bytes to FPGA in loop
//    t = 0;
//    n = file.size >> 3;
//    ptr = sector_buffer;
//    do
//    {
//        // read sector if 512 (64*8) bytes done
//        if ((t & 0x3F) == 0)
//        {
//            if (t & (1<<10))
//                *AT91C_PIOA_CODR = DISKLED;
//            else
//                *AT91C_PIOA_SODR = DISKLED;
//
//            if ((t & 0x1FF) == 0)
//                printf("*");
//
//            if (!FileRead(&file, sector_buffer))
//                return(0);
//
//            ptr = sector_buffer;
//        }
//
//        // send data in packets of 8 bytes
//        ShiftFpga(*ptr++);
//        ShiftFpga(*ptr++);
//        ShiftFpga(*ptr++);
//        ShiftFpga(*ptr++);
//        ShiftFpga(*ptr++);
//        ShiftFpga(*ptr++);
//        ShiftFpga(*ptr++);
//        ShiftFpga(*ptr++);
//
//        t++;
//
//        // read next sector if 512 (64*8) bytes done
//        if ((t & 0x3F) == 0)
//            FileNextSector(&file);
//
//    }
//    while (t < n);
//
//    // disable outputs
//    *AT91C_PIOA_ODR = CCLK | DIN | PROG_B;
//
//    printf("]\r");
//    printf("FPGA bitstream loaded\r");
//    *AT91C_PIOA_CODR = DISKLED;
//
//    // check if DONE is high
//    if (*AT91C_PIOA_PDSR & DONE)
//        return(1);
//
//    printf("FPGA done is NOT high!\r");
//    FatalError(5);
//    return 0;
//}


static int rom_nextchar(const char *c)
{
	static int *p;
	static int t;
	static int s;
	if(c)
	{
		p=(int *)c;
		s=0;
	}
	if(s==0)
		t=*p++;
	else
		t<<=8;
	s=(s+1)&3;
	return(t>>24);
}


static int rom_strlen(const char *str)
{
	int c=rom_nextchar(str);
	int r=0;
	while(1)
	{
		if(c)
		{
			++r;
			c=rom_nextchar(0);
		}
		else
			return(r);
	}
}


// print message on the boot screen
int BootPrint(const char *text)
{
    unsigned int c1, c2, c3, c4;
    unsigned int cmd;
    const char *p;
    unsigned int n;

    p = text;
    n = rom_strlen(text);

    cmd = 1;
    while (1)
    {
        EnableFpga();
//		c1=SPIW(0x1001);
        c1 = SPI(0x10); // track read command
        c2 = SPI(0x01); // disk present
		SPIW(0);
//        SPI(0);
//        SPI(0);
//		c3 = SPIW(0);
        c3 = SPI(0);
        c4 = SPI(0);

        if (c1 & (CMD_RDTRK<<8))
        {
            if (cmd)
            { // command phase
                if (c3 == 0x80 && c4 == 0x06) // command packet size must be 12 bytes
//                if (c3 == 0x8006) // command packet size must be 12 bytes
                {
                    cmd = 0;
                    SPIW(CMD_HDRID); // command header
//                    SPI(CMD_HDRID >> 8); // command header
 //                   SPI(CMD_HDRID & 0xFF);
					SPIW(0x0001);
//                    SPI(0x00); // cmd: 0x0001 = print text
 //                   SPI(0x01);
                    // data packet size in bytes
					SPIW(0x0000);
//                    SPI(0x00);
//                    SPI(0x00);
					SPIW(n+2);
//                    SPI(0x00);
//                    SPI(n+2); // +2 because only even byte count is possible to send and we have to send termination zero byte
                    // don't care
					SPIW(0x0000);
//                    SPI(0x00);
//                    SPI(0x00);
					SPIW(0x0000);
//                    SPI(0x00);
//                    SPI(0x00);
                }
                else
                    break;
            }
            else
            { // data phase
                if (c3 == 0x80 && c4 == ((n + 2) >> 1))
//                if (c3 == (0x8000 | ((n + 2) >> 1)))
                {
                    n = (c3&0xff) << 1;
                    c4 = rom_nextchar(text);
                    while (n--)
                    {
                        SPI(c4);
                        if (c4) // if current character is not zero go to next one
                            c4=rom_nextchar(0);
                    }
                    DisableFpga();
                    return 1;
                }
                else
                    break;
            }
        }
        DisableFpga();
    }
    DisableFpga();
    return 0;
}

unsigned int GetFPGAStatus(void)
{
    unsigned int status;

    EnableFpga();
    status = SPIW(0)>>8;
//    SPI(0);
	SPIW(0x0000);
//    SPI(0);
//    SPI(0);
	SPIW(0x0000);
//    SPI(0);
//    SPI(0);
    DisableFpga();

    return status;
}

