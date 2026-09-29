#include <sys/types.h>
main()
{
pid_t pid;
pid = fork();
if (pid == 0)
printf("\n I'm the child process");
else if (pid > 0)
printf("\n I'm the parent process. My child pid is %d", pid);
else
perror("error in fork");
}
