/* See LICENSE.dwm file for copyright and license details. */

void die(const char *fmt, ...) __attribute__((format(printf, 1, 2), noreturn));
void *ecalloc(size_t nmemb, size_t size);
int fd_set_nonblock(int fd);
