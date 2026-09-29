#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>



int main(){

	int fd;
	char a[100];
	char b[] = "I like OS labs";
	//open a file
	fd = open("test1.txt",O_RDWR);
	printf("FD value :%d\n", fd);
	
	
	if(fd!=-1){
		printf("write starts here:....\n");
		write(fd, b, sizeof(b));
		printf("write ends here:..\n");
		//close(fd);
	
		lseek(fd,0,SEEK_SET);
		printf("Read starts here:....\n");
		read(fd,a,sizeof(a));
		printf("Data read:%s\n",a);
		printf("Read ends here:....\n");
		//seek_cur
		lseek(fd,-5,SEEK_CUR);
		read(fd, a, sizeof(a));
		
		printf("Data read:%s\n",a);
		
		printf("read lseek_cur ends here:..\n");
				
		close(fd);
		

	}


	return 0;
}


/*	int d,d1;
	d = open("test.txt",O_RDONLY);
	printf("d: %d\n",d);
	close(d);
	
	d1 = open("test.txt",O_WRONLY);
	printf("d1: %d\n",d1);
	close(d1);


	return 0;
	
*/

/*

char b[] = "I like OS labs";
	//printf("Give input:\n");
	write(1, b, sizeof(b));
	//printf("Data Read:%s\n",a);
	
*/
