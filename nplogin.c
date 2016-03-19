/* This c program logs into neopets, taking two arguments: username and password */

#define COOKIE "cookie"

#define _GNU_SOURCE
#include <stdio.h>
#include <curl/curl.h>
#include <stdlib.h>
#include <syslog.h>
#include <time.h>
#include <unistd.h>

/* used to make curl not write output to stdout */
size_t write_data(void *buffer, size_t size, size_t nmemb, void *userp)
{
   return size * nmemb;
}

//////////////////////////
//neopets login
//////////////////////////
void neopets_login(char* username, char* password){
    CURL* curl = curl_easy_init();
    char* post;
    //set options for login
    curl_easy_setopt(curl, CURLOPT_URL, "http://www.neopets.com/login.phtml");
    curl_easy_setopt(curl, CURLOPT_COOKIEJAR, COOKIE);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
    curl_easy_setopt(curl, CURLOPT_POST, 1L);

    asprintf(&post, "username=%s&password=%s", username, password);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, post);

    //perform login
    curl_easy_perform(curl);

    //cleanup
    curl_easy_cleanup(curl);
    free(post);
}


//////////////////////
//main
//////////////////////
int main(int argc, char *argv[]){
   
    //init syslog
    openlog("nplogin", LOG_PERROR | LOG_PID | LOG_NDELAY, LOG_USER);

    //login to neopets
    syslog(LOG_INFO, "Logging into Neopets");
    neopets_login(argv[1], argv[2]);

    //clean up
    closelog();

    exit(EXIT_SUCCESS);
}
