/*
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 *
 * Developed at SunPro, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 */

/*
 * Originally based on fdlibm.h 5.1 via FreeBSD.
 */

#pragma once

#include <sys/cdefs.h>
#include <limits.h>

__BEGIN_DECLS

/* C11. */

typedef double __double_t;
typedef __double_t double_t;
typedef float __float_t;
typedef __float_t float_t;

#define HUGE_VAL __builtin_huge_val()
#define HUGE_VALF __builtin_huge_valf()
#define HUGE_VALL __builtin_huge_vall()

#define INFINITY __builtin_inff()

#define NAN __builtin_nanf("")

#define FP_INFINITE 0x01
#define FP_NAN 0x02
#define FP_NORMAL 0x04
#define FP_SUBNORMAL 0x08
#define FP_ZERO 0x10

#if defined(__FP_FAST_FMA)
#define FP_FAST_FMA 1
#endif
#if defined(__FP_FAST_FMAF)
#define FP_FAST_FMAF 1
#endif
#if defined(__FP_FAST_FMAL)
#define FP_FAST_FMAL 1
#endif

#define FP_ILOGB0 (-INT_MAX)
#define FP_ILOGBNAN INT_MAX

#define MATH_ERRNO 1
#define MATH_ERREXCEPT 2
#define math_errhandling MATH_ERREXCEPT

#define fpclassify(x) __builtin_fpclassify(FP_NAN, FP_INFINITE, FP_NORMAL, FP_SUBNORMAL, FP_ZERO, x)

#define isfinite(x) __builtin_isfinite(x)

#define isnormal(x) __builtin_isnormal(x)

#define signbit(x) __builtin_signbit(x)

#define isinf(x) __builtin_isinf(x)
#define isnan(x) __builtin_isnan(x)

double acos(double __x)__NOEXCEPT ;
float acosf(float __x)__NOEXCEPT ;
long double acosl(long double __x)__NOEXCEPT ;

double asin(double __x)__NOEXCEPT ;
float asinf(float __x)__NOEXCEPT ;
long double asinl(long double __x)__NOEXCEPT ;

double atan(double __x)__NOEXCEPT ;
float atanf(float __x)__NOEXCEPT ;
long double atanl(long double __x)__NOEXCEPT ;

double atan2(double __y, double __x)__NOEXCEPT ;
float atan2f(float __y, float __x)__NOEXCEPT ;
long double atan2l(long double __y, long double __x)__NOEXCEPT ;

double cos(double __x)__NOEXCEPT ;
float cosf(float __x)__NOEXCEPT ;
long double cosl(long double __x)__NOEXCEPT ;

double sin(double __x)__NOEXCEPT ;
float sinf(float __x)__NOEXCEPT ;
long double sinl(long double __x)__NOEXCEPT ;

double tan(double __x)__NOEXCEPT ;
float tanf(float __x)__NOEXCEPT ;
long double tanl(long double __x)__NOEXCEPT ;

double acosh(double __x)__NOEXCEPT ;
float acoshf(float __x)__NOEXCEPT ;
long double acoshl(long double __x)__NOEXCEPT ;

double asinh(double __x)__NOEXCEPT ;
float asinhf(float __x)__NOEXCEPT ;
long double asinhl(long double __x)__NOEXCEPT ;

double atanh(double __x)__NOEXCEPT ;
float atanhf(float __x)__NOEXCEPT ;
long double atanhl(long double __x)__NOEXCEPT ;

double cosh(double __x)__NOEXCEPT ;
float coshf(float __x)__NOEXCEPT ;
long double coshl(long double __x)__NOEXCEPT ;

double sinh(double __x)__NOEXCEPT ;
float sinhf(float __x)__NOEXCEPT ;
long double sinhl(long double __x)__NOEXCEPT ;

double tanh(double __x)__NOEXCEPT ;
float tanhf(float __x)__NOEXCEPT ;
long double tanhl(long double __x)__NOEXCEPT ;

double exp(double __x)__NOEXCEPT ;
float expf(float __x)__NOEXCEPT ;
long double expl(long double __x)__NOEXCEPT ;

double exp2(double __x)__NOEXCEPT ;
float exp2f(float __x)__NOEXCEPT ;
long double exp2l(long double __x)__NOEXCEPT ;

double expm1(double __x)__NOEXCEPT ;
float expm1f(float __x)__NOEXCEPT ;
long double expm1l(long double __x)__NOEXCEPT ;

double frexp(double __x, int* __exponent) __NOEXCEPT __attribute__((nonnull(2)));
float frexpf(float __x, int* __exponent) __NOEXCEPT __attribute__((nonnull(2)));
long double frexpl(long double __x, int* __exponent) __NOEXCEPT __attribute__((nonnull(2)));

int ilogb(double __x) __NOEXCEPT __attribute_const__;
int ilogbf(float __x) __NOEXCEPT __attribute_const__;
int ilogbl(long double __x) __NOEXCEPT __attribute_const__;

double ldexp(double __x, int __exponent)__NOEXCEPT ;
float ldexpf(float __x, int __exponent)__NOEXCEPT ;
long double ldexpl(long double __x, int __exponent)__NOEXCEPT ;

double log(double __x)__NOEXCEPT ;
float logf(float __x)__NOEXCEPT ;
long double logl(long double __x)__NOEXCEPT ;

double log10(double __x)__NOEXCEPT ;
float log10f(float __x)__NOEXCEPT ;
long double log10l(long double __x)__NOEXCEPT ;

double log1p(double __x)__NOEXCEPT ;
float log1pf(float __x)__NOEXCEPT ;
long double log1pl(long double __x)__NOEXCEPT ;

double log2(double __x)__NOEXCEPT ;
float log2f(float __x)__NOEXCEPT ;
long double log2l(long double __x)__NOEXCEPT ;

double logb(double __x)__NOEXCEPT ;
float logbf(float __x)__NOEXCEPT ;
long double logbl(long double __x)__NOEXCEPT ;

double modf(double __x, double* __integral_part) __NOEXCEPT __attribute__((nonnull(2)));
float modff(float __x, float* __integral_part) __NOEXCEPT __attribute__((nonnull(2)));
long double modfl(long double __x, long double* __integral_part) __NOEXCEPT __attribute__((nonnull(2)));

double scalbn(double __x, int __exponent)__NOEXCEPT ;
float scalbnf(float __x, int __exponent)__NOEXCEPT ;
long double scalbnl(long double __x, int __exponent)__NOEXCEPT ;

double scalbln(double __x, long __exponent)__NOEXCEPT ;
float scalblnf(float __x, long __exponent)__NOEXCEPT ;
long double scalblnl(long double __x, long __exponent)__NOEXCEPT ;

double cbrt(double __x)__NOEXCEPT ;
float cbrtf(float __x)__NOEXCEPT ;
long double cbrtl(long double __x)__NOEXCEPT ;

double fabs(double __x) __NOEXCEPT __attribute_const__;
float fabsf(float __x) __NOEXCEPT __attribute_const__;
long double fabsl(long double __x) __NOEXCEPT __attribute_const__;

double hypot(double __x, double __y)__NOEXCEPT ;
float hypotf(float __x, float __y)__NOEXCEPT ;
long double hypotl(long double __x, long double __y)__NOEXCEPT ;

double pow(double __x, double __y)__NOEXCEPT ;
float powf(float __x, float __y)__NOEXCEPT ;
long double powl(long double __x, long double __y)__NOEXCEPT ;

double sqrt(double __x)__NOEXCEPT ;
float sqrtf(float __x)__NOEXCEPT ;
long double sqrtl(long double __x)__NOEXCEPT ;

double erf(double __x)__NOEXCEPT ;
float erff(float __x)__NOEXCEPT ;
long double erfl(long double __x)__NOEXCEPT ;

double erfc(double __x)__NOEXCEPT ;
float erfcf(float __x)__NOEXCEPT ;
long double erfcl(long double __x)__NOEXCEPT ;

double lgamma(double __x)__NOEXCEPT ;
float lgammaf(float __x)__NOEXCEPT ;
long double lgammal(long double __x)__NOEXCEPT ;

double tgamma(double __x)__NOEXCEPT ;
float tgammaf(float __x)__NOEXCEPT ;
long double tgammal(long double __x)__NOEXCEPT ;

double ceil(double __x)__NOEXCEPT ;
float ceilf(float __x)__NOEXCEPT ;
long double ceill(long double __x)__NOEXCEPT ;

double floor(double __x)__NOEXCEPT ;
float floorf(float __x)__NOEXCEPT ;
long double floorl(long double __x)__NOEXCEPT ;

double nearbyint(double __x)__NOEXCEPT ;
float nearbyintf(float __x)__NOEXCEPT ;
long double nearbyintl(long double __x)__NOEXCEPT ;

double rint(double __x)__NOEXCEPT ;
float rintf(float __x)__NOEXCEPT ;
long double rintl(long double __x)__NOEXCEPT ;

long lrint(double __x)__NOEXCEPT ;
long lrintf(float __x)__NOEXCEPT ;
long lrintl(long double __x)__NOEXCEPT ;

long long llrint(double __x)__NOEXCEPT ;
long long llrintf(float __x)__NOEXCEPT ;
long long llrintl(long double __x)__NOEXCEPT ;

double round(double __x)__NOEXCEPT ;
float roundf(float __x)__NOEXCEPT ;
long double roundl(long double __x)__NOEXCEPT ;

long lround(double __x)__NOEXCEPT ;
long lroundf(float __x)__NOEXCEPT ;
long lroundl(long double __x)__NOEXCEPT ;

long long llround(double __x)__NOEXCEPT ;
long long llroundf(float __x)__NOEXCEPT ;
long long llroundl(long double __x)__NOEXCEPT ;

double trunc(double __x)__NOEXCEPT ;
float truncf(float __x)__NOEXCEPT ;
long double truncl(long double __x)__NOEXCEPT ;

double fmod(double __x, double __y)__NOEXCEPT ;
float fmodf(float __x, float __y)__NOEXCEPT ;
long double fmodl(long double __x, long double __y)__NOEXCEPT ;

double remainder(double __x, double __y)__NOEXCEPT ;
float remainderf(float __x, float __y)__NOEXCEPT ;
long double remainderl(long double __x, long double __y)__NOEXCEPT ;

double remquo(double __x, double __y, int* __quotient_bits) __NOEXCEPT __attribute__((nonnull(3)));
float remquof(float __x, float __y, int* __quotient_bits) __NOEXCEPT __attribute__((nonnull(3)));
long double remquol(long double __x, long double __y, int* __quotient_bits) __NOEXCEPT __attribute__((nonnull(3)));

double copysign(double __value, double __sign) __NOEXCEPT __attribute_const__;
float copysignf(float __value, float __sign) __NOEXCEPT __attribute_const__;
long double copysignl(long double __value, long double __sign) __NOEXCEPT __attribute_const__;

double nan(const char* __kind) __NOEXCEPT __attribute_const__ __attribute__((nonnull(1)));
float nanf(const char* __kind) __NOEXCEPT __attribute_const__ __attribute__((nonnull(1)));
long double nanl(const char* __kind) __NOEXCEPT __attribute_const__ __attribute__((nonnull(1)));

double nextafter(double __x, double __y)__NOEXCEPT ;
float nextafterf(float __x, float __y)__NOEXCEPT ;
long double nextafterl(long double __x, long double __y)__NOEXCEPT ;

double nexttoward(double __x, long double __y)__NOEXCEPT ;
float nexttowardf(float __x, long double __y)__NOEXCEPT ;
long double nexttowardl(long double __x, long double __y)__NOEXCEPT ;

double fdim(double __x, double __y)__NOEXCEPT ;
float fdimf(float __x, float __y)__NOEXCEPT ;
long double fdiml(long double __x, long double __y)__NOEXCEPT ;

double fmax(double __x, double __y) __NOEXCEPT __attribute_const__;
float fmaxf(float __x, float __y) __NOEXCEPT __attribute_const__;
long double fmaxl(long double __x, long double __y) __NOEXCEPT __attribute_const__;

double fmin(double __x, double __y) __NOEXCEPT __attribute_const__;
float fminf(float __x, float __y) __NOEXCEPT __attribute_const__;
long double fminl(long double __x, long double __y) __NOEXCEPT __attribute_const__;

double fma(double __x, double __y, double __z)__NOEXCEPT ;
float fmaf(float __x, float __y, float __z)__NOEXCEPT ;
long double fmal(long double __x, long double __y, long double __z)__NOEXCEPT ;

#define isgreater(x, y) __builtin_isgreater((x), (y))
#define isgreaterequal(x, y) __builtin_isgreaterequal((x), (y))
#define isless(x, y) __builtin_isless((x), (y))
#define islessequal(x, y) __builtin_islessequal((x), (y))
#define islessgreater(x, y) __builtin_islessgreater((x), (y))
#define isunordered(x, y) __builtin_isunordered((x), (y))

/* POSIX extensions. */

extern int signgam;

double j0(double __x)__NOEXCEPT ;
double j1(double __x)__NOEXCEPT ;
double jn(int __n, double __x)__NOEXCEPT ;
double y0(double __x)__NOEXCEPT ;
double y1(double __x)__NOEXCEPT ;
double yn(int __n, double __x)__NOEXCEPT ;

#define M_E		2.7182818284590452354	/* e */
#define M_LOG2E		1.4426950408889634074	/* log 2e */
#define M_LOG10E	0.43429448190325182765	/* log 10e */
#define M_LN2		0.69314718055994530942	/* log e2 */
#define M_LN10		2.30258509299404568402	/* log e10 */
#define M_PI		3.14159265358979323846	/* pi */
#define M_PI_2		1.57079632679489661923	/* pi/2 */
#define M_PI_4		0.78539816339744830962	/* pi/4 */
#define M_1_PI		0.31830988618379067154	/* 1/pi */
#define M_2_PI		0.63661977236758134308	/* 2/pi */
#define M_2_SQRTPI	1.12837916709551257390	/* 2/sqrt(pi) */
#define M_SQRT2		1.41421356237309504880	/* sqrt(2) */
#define M_SQRT1_2	0.70710678118654752440	/* 1/sqrt(2) */

#define M_El            2.718281828459045235360287471352662498L /* e */
#define M_LOG2El        1.442695040888963407359924681001892137L /* log 2e */
#define M_LOG10El       0.434294481903251827651128918916605082L /* log 10e */
#define M_LN2l          0.693147180559945309417232121458176568L /* log e2 */
#define M_LN10l         2.302585092994045684017991454684364208L /* log e10 */
#define M_PIl           3.141592653589793238462643383279502884L /* pi */
#define M_PI_2l         1.570796326794896619231321691639751442L /* pi/2 */
#define M_PI_4l         0.785398163397448309615660845819875721L /* pi/4 */
#define M_1_PIl         0.318309886183790671537767526745028724L /* 1/pi */
#define M_2_PIl         0.636619772367581343075535053490057448L /* 2/pi */
#define M_2_SQRTPIl     1.128379167095512573896158903121545172L /* 2/sqrt(pi) */
#define M_SQRT2l        1.414213562373095048801688724209698079L /* sqrt(2) */
#define M_SQRT1_2l      0.707106781186547524400844362104849039L /* 1/sqrt(2) */

#define MAXFLOAT	((float)3.40282346638528860e+38)

/* BSD extensions. */

#if defined(__USE_BSD)
#define HUGE MAXFLOAT
#endif

/* Extensions in both BSD and GNU. */

#if defined(__USE_BSD) || defined(__USE_GNU)
double gamma(double __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
double scalb(double __x, double __exponent)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
double drem(double __x, double __y)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
int finite(double __x) __NOEXCEPT __attribute_const__;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
int isinff(float __x) __NOEXCEPT __attribute_const__;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
int isnanf(float __x) __NOEXCEPT __attribute_const__;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
double gamma_r(double __x, int* __sign) __attribute__((nonnull(2)));
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
double lgamma_r(double __x, int* __sign) __NOEXCEPT __attribute__((nonnull(2)));
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
double significand(double __x)__NOEXCEPT ;
#endif

#if (defined(__USE_BSD) || defined(__USE_GNU))
long double lgammal_r(long double __x, int* __sign) __NOEXCEPT __attribute__((nonnull(2)));
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
long double significandl(long double __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float dremf(float __x, float __y)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
int finitef(float __x) __NOEXCEPT __attribute_const__;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float gammaf(float __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float j0f(float __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float j1f(float __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float jnf(int __n, float __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float scalbf(float __x, float __exponent)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float y0f(float __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float y1f(float __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float ynf(int __n, float __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float gammaf_r(float __x, int* __sign) __attribute__((nonnull(2)));
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float lgammaf_r(float __x, int* __sign) __NOEXCEPT __attribute__((nonnull(2)));
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
float significandf(float __x)__NOEXCEPT ;
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
void sincos(double __x, double* __sin, double* __cos) __NOEXCEPT __attribute__((nonnull(2,3)));
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
void sincosf(float __x, float* __sin, float* __cos) __NOEXCEPT __attribute__((nonnull(2,3)));
#endif

#if defined(__USE_BSD) || defined(__USE_GNU)
void sincosl(long double __x, long double* __sin, long double* __cos) __NOEXCEPT __attribute__((nonnull(2,3)));
#endif

#if defined(__USE_GNU)
int isinfl(long double __x) __NOEXCEPT __attribute_const__;
#endif

#if defined(__USE_GNU)
int isnanl(long double __x) __NOEXCEPT __attribute_const__;
#endif

__END_DECLS
