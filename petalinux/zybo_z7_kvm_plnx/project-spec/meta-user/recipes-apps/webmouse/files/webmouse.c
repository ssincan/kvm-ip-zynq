#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    const char* query = getenv("QUERY_STRING");
    const char* delim = "&";
    char *token;
    char *fix;
    long dx, dy, lc, rc, cdx, cdy;

    if(query)
    {

        token = strtok(query, delim);

        while(token != NULL)
        {
            fix = strchr(token, '=');
            *fix = '\0';
            if(strcmp(token, "dx") == 0)
                dx = atol(fix+1);
            else if(strcmp(token, "dy") == 0)
                dy = atol(fix+1);
            else if(strcmp(token, "lc") == 0)
                lc = atol(fix+1);
            else if(strcmp(token, "rc") == 0)
                rc = atol(fix+1);
            token = strtok(NULL, delim);
        }

        while(dx || dy)
        {
            if(dx <= -127)
                cdx = -127;
            else if(dx >= 127)
                cdx = 127;
            else
                cdx = dx;
            if(dy <= -127)
                cdy = -127;
            else if(dy >= 127)
                cdy = 127;
            else
                cdy = dy;
            dx -= cdx;
            dy -= cdy;
            fprintf(stdout, "%li %li\n", cdx, cdy);
        }

        if(lc)
            fprintf(stdout, "--b1\n");

        if(rc)
            fprintf(stdout, "--b2\n");

    }

    return 0;
}
