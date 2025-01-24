// generic stuff common to netgen and runtime

#ifndef MISC_H
#define MISC_H

// roundoff-error-safe integer-exact equivalent of (int)ceil((double)a/(double)b)
// only works as expected for integer types -> template function not used intentionally
inline int ceil_div(int a, int b) { return (a + b - 1) / b; }
inline unsigned int ceil_div(unsigned int a, unsigned int b) { return (a + b - 1) / b; }

// FIXME valid for positive numbers only
inline int round_up(int a, int multiple) { return ceil_div(a, multiple)*multiple; }
inline unsigned int round_up(unsigned int a, unsigned int multiple) { return ceil_div(a, multiple)*multiple; }

#endif // MISC_H
