#include <stddef.h>

void *memcpy(void *dst, const void *src, size_t len)
{
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;

    while (len-- != 0u) {
        *d++ = *s++;
    }
    return dst;
}

void *memset(void *dst, int value, size_t len)
{
    unsigned char *d = (unsigned char *)dst;

    while (len-- != 0u) {
        *d++ = (unsigned char)value;
    }
    return dst;
}

int memcmp(const void *lhs, const void *rhs, size_t len)
{
    const unsigned char *a = (const unsigned char *)lhs;
    const unsigned char *b = (const unsigned char *)rhs;

    while (len-- != 0u) {
        if (*a != *b) {
            return (int)*a - (int)*b;
        }
        ++a;
        ++b;
    }
    return 0;
}
