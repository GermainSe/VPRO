//
// Created by gesper on 25.07.19.
//

#ifndef VPRO_TUTORIAL_CNN_CNN_C_REF_H
#define VPRO_TUTORIAL_CNN_CNN_C_REF_H

#include <QVector>
#include <cmath>
#include <png++/png.hpp>
#include <algorithm>
#include <vector>
#include <numeric>
#include <type_traits>
#include <immintrin.h> // AVX
#include <QDebug>
#include <QFile>
#include <simulator/helper/typeConversion.h>

template<typename T>
class dynamic_matrix : private std::vector<T>
{
    using std::vector<T>::begin;
    using std::vector<T>::at;
    using std::vector<T>::size;
    using std::vector<T>::operator[];
    using std::vector<T>::end;

private:
    size_t m_lines;
    size_t m_cols;

public:

    dynamic_matrix() { std::fill( begin(), end(), T{0} ); }
    dynamic_matrix( size_t m, size_t n ) : std::vector<T>( m*n, 0 ), m_lines{m}, m_cols{n} {}

    size_t lines() const { return m_lines; }
    size_t cols() const { return m_cols; }

    T& operator()( size_t m, size_t n ) { return at( m*m_cols + n ); }
    const T& operator()( size_t m, size_t n ) const { return at( m*m_cols + n ); }


    static T loadImage(const char *filename)
    {
        png::image<png::rgb_pixel> image(filename);
        T imageMatrix = T(image.get_height(), image.get_width());
        int h,w;
        for (h=0 ; h<image.get_height() ; h++) {
            for (w=0 ; w<image.get_width() ; w++) {
                imageMatrix(h,w) = (image[h][w].red + image[h][w].green + image[h][w].blue) / 3;
            }
        }

//        printf("Read IMG\n");
//        imageMatrix.print();

        return imageMatrix;
    }


    static T loadFromMM(const int16_t *mem, int x, int y, int stride_x = 0){
        T imageMatrix = T(y, x);
        int h,w;
        for (h=0 ; h<y ; h++) {
            for (w=0 ; w<x ; w++) {
                int16_t data = mem[w + h*(x+stride_x)];
                imageMatrix(h,w) = data;
            }
        }
//        printf("Loaded from MM:\n");
//        imageMatrix.print();
        return imageMatrix;
    }

    static T loadBinary(const char *filename) {
        std::ifstream ifs(filename, std::ios::binary | std::ios::ate);
        if (!ifs) {
            printf_error("...)\n\t Input file could not be opened!\n");
            //continue;
        }
        int pos = ifs.tellg(); // size in byte
        ifs.seekg(0, std::ios::beg); // go to position 0
        int height = sqrt(pos / 2); // size = h*w (h=w!)
        int width = sqrt(pos / 2);
        T imageMatrix = T(height, width);
        int h,w;
        for (h=0 ; h<imageMatrix.lines() ; h++) {
            for (w=0 ; w<imageMatrix.cols() ; w++) {

                char buffer[2];
                ifs.read(buffer, 2); // read 2 byte
                char b1 = buffer[1];
                char b0 = buffer[0];
                buffer[0] = b0;
                buffer[1] = b1;

                int64_t value = int64_t(*((int16_t*)&buffer));
                imageMatrix(h,w) = value;
            }
        }
//        printf("Read IMG\n");
//        imageMatrix.print();
        return imageMatrix;
    }

    static dynamic_matrix<T> loadBinary(const char *filename, int x, int y){
        dynamic_matrix<T> imageMatrix = dynamic_matrix<T>(y, x);
        int h,w;
        QFile file = QFile(QString(filename));
        file.open(QIODevice::ReadOnly);
        QDataStream in(&file);
        qint16 data;
        for (h=0 ; h<y ; h++) {
            for (w=0 ; w<x ; w++) {
                in >> data;
                imageMatrix(h,w) = T(data);
            }
        }
        return imageMatrix;
    }

    static void saveImage(T &image, const char *filename)
    {
        int height = image.cols();
        int width = image.lines();
        png::image<png::rgb_pixel> imageFile(width, height);
        int x,y;
        for (y=0 ; y<height ; y++) {
            for (x=0 ; x<width ; x++) {
                imageFile[y][x].red = image(y, x);
                imageFile[y][x].green = image(y, x);
                imageFile[y][x].blue = image(y, x);
            }
        }
        imageFile.write(filename);
    }

    void uniform_assign( const T& v )
    {
        std::fill( begin(), end(), v );
    }

    bool compare( const dynamic_matrix<T>& other ) const
    {
        for( auto i=0u; i<m_lines*m_cols; i++ )
            if ( other[i] != (*this)[i] )
                return false;
        return true;
    }

    dynamic_matrix<T> convolve( const dynamic_matrix<T>& kernel, const int stride = 1) const
    {
        dynamic_matrix<T> output;
        if (stride == 1){

            if ((m_lines == 1 || m_cols == 1) && (kernel.m_lines == 3 || kernel.m_cols == 3)){
                output = dynamic_matrix<T>( 1, 1 );
                output(0,0) = (*this)(0, 0) * kernel(1, 1);
                return output;
            }

            const auto steps_lines = m_lines - kernel.m_lines + 1;
            const auto steps_cols = m_cols - kernel.m_cols + 1;

            bool zeroPadding = (kernel.m_lines > 1);
            int padding = 0;
            if (zeroPadding){
                padding = (kernel.m_lines - 1) / 2;
                output = dynamic_matrix<T>( m_lines, m_cols );
            } else {
                output = dynamic_matrix<T>( steps_lines, steps_cols );
            }

            if (zeroPadding) {
                // add zero padding
                // calculate padding width stripe on top, bottom, left and right
                for (size_t i = 0; i < m_lines; ++i) { // left
                    for (ssize_t j = 0; j < padding; ++j) { // col width padding
                        for (size_t k = 0; k < kernel.m_lines; ++k) { // kernel lines
                            for (size_t l = 0; l < kernel.m_cols; ++l) { // kernel columns
                                // index of input signal, used for checking boundary
                                ssize_t ii = i + k - padding;
                                ssize_t jj = j + l - padding;
                                if (ii >= 0 && jj >= 0 && ii < ssize_t(m_lines) && jj < ssize_t(m_cols))
                                    output(i, j) += (*this)(ii, jj) * kernel(k, l);
                            }
                        }
                    }
                }
                for (size_t i = 0; i < m_lines; ++i) { // right
                    for (ssize_t j = m_cols - 1; j > ssize_t(m_cols) - 1 - padding; --j) {  // col end  - (end-k)
                        for (size_t k = 0; k < kernel.m_lines; ++k) { // kernel lines
                            for (size_t l = 0; l < kernel.m_cols; ++l) { // kernel columns
                                // index of input signal, used for checking boundary
                                ssize_t ii = i + k - padding;
                                ssize_t jj = j + l - padding;
                                if (ii >= 0 && jj >= 0 && ii < ssize_t(m_lines) && jj < ssize_t(m_cols))
                                    output(i, j) += (*this)(ii, jj) * kernel(k, l);
                            }
                        }
                    }
                }
                for (ssize_t j = padding; j < ssize_t(m_cols) - padding; ++j) { // top without last (already from left)
                    for (ssize_t i = 0; i < padding; ++i) { // line 0 - k
                        for (size_t k = 0; k < kernel.m_lines; ++k) { // kernel lines
                            for (size_t l = 0; l < kernel.m_cols; ++l) { // kernel columns
                                // index of input signal, used for checking boundary
                                ssize_t ii = i + k - padding;
                                ssize_t jj = j + l - padding;
                                if (ii >= 0 && jj >= 0 && ii < ssize_t(m_lines) && jj < ssize_t(m_cols))
                                    output(i, j) += (*this)(ii, jj) * kernel(k, l);
                            }
                        }
                    }
                }
                for (ssize_t j = padding; j < ssize_t(m_cols) - padding; ++j) { // bottom without last (already from left)
                    for (ssize_t i = m_lines - 1; i > ssize_t(m_lines) - 1 - padding; --i) { // line end - (end-k)
                        for (size_t k = 0; k < kernel.m_lines; ++k) { // kernel lines
                            for (size_t l = 0; l < kernel.m_cols; ++l) { // kernel columns
                                // index of input signal, used for checking boundary
                                ssize_t ii = i + k - padding;
                                ssize_t jj = j + l - padding;
                                if (ii >= 0 && jj >= 0 && ii < ssize_t(m_lines) && jj < ssize_t(m_cols))
                                    output(i, j) += (*this)(ii, jj) * kernel(k, l);
                            }
                        }
                    }
                }
            }

            // valid area in middle of image
            for(size_t i=0; i <steps_lines; ++i ) // lines
            {
                for(size_t j=0; j<steps_cols; ++j ) // columns
                {
                    for(size_t k=0; k<kernel.m_lines; ++k ) // kernel lines
                    {
                        for(size_t l=0; l<kernel.m_cols; ++l ) // kernel columns
                        {
                            // index of input signal, used for checking boundary
                            ssize_t ii = i + k;
                            ssize_t jj = j + l;

                            output(i+padding,j+padding) += (*this)(ii,jj) * kernel(k,l);
                        }
                    }
                }
            }
        } else {
//            printf("KERNEL:\n");
//            kernel.print();
            auto tmp = this->convolve(kernel, 1);
            // without stride

//            printf("(*this):\n");
//            print();
            // subsample
            output = dynamic_matrix<T>( ceil(float(m_lines) / stride), ceil(float(m_cols) /stride));
            for (int x = m_cols-1; x >= 0; x-=stride){
                for (int y = m_lines-1; y >= 0; y-=stride){
                    // block of 4
//                    tmp(x-1,y-1) // maybe invalid
//                    tmp(x-1,y) // maybe invalid
//                    tmp(x,y-1) // maybe invalid
//                    tmp(x,y) // take most bottom right of stride block
                    output(y / stride, x /stride) = tmp(y, x);
                }
            }
//            printf("output:\n");
//            output.print();
        }

//        printf("KERNEL:\n");
//        kernel.print();
//
//        printf("(*this):\n");
//        print();
//
//        printf("output:\n");
//        output.print();

        return output;
    }

    dynamic_matrix<T> add( const T& bias ) const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );

        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for( auto j=0u; j<m_cols; ++j ) // columns
            {
                output( i, j ) = (*this)(i,j) + bias;
            }
        }

//        printf("bias (*this):\n");
//        print();

        return output;
    }

    dynamic_matrix<T> divide( const float &div, const int &shift ) const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );

        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for( auto j=0u; j<m_cols; ++j ) // columns
            {
                output( i, j ) = T((float((*this)(i,j)) / div) * pow(2,shift));
            }
        }

        return output;
    }

    T getMax() const{
        T max = std::numeric_limits<T>::min();
        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for (auto j = 0u; j < m_cols; ++j) // columns
            {
                max = ((*this)(i,j) > max)? (*this)(i,j) : max;
            }
        }
        return max;
    }
    T getMin() const{
        T min = std::numeric_limits<T>::max();
        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for (auto j = 0u; j < m_cols; ++j) // columns
            {
                min = ((*this)(i,j) < min)? (*this)(i,j) : min;
            }
        }
        return min;
    }

    dynamic_matrix<T> cut24() const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );

        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for( auto j=0u; j<m_cols; ++j ) // columns
            {
                uint64_t val = uint64_t((*this)(i,j));
                val = *__24to64signed(val);
                output( i, j ) = T(val);
                if ((*this)(i,j) != T(val)){
                    printf("[ERROR] on cut to 24 bit. lost precision. %li -> %li !\n", (*this)(i,j), val);
                    exit(0);
                }
            }
        }
        return output;
    }

    dynamic_matrix<T> saturate16() const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );

        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for( auto j=0u; j<m_cols; ++j ) // columns
            {
                output( i, j ) = T(((*this)(i,j) < int16_t(0x8000)) ? int16_t(0x8000) : (((*this)(i,j) > int16_t(0x7FFF))? int16_t(0x7FFF) : (*this)(i,j)));
            }
        }
        return output;
    }

    dynamic_matrix<T> cut16() const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );

        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for( auto j=0u; j<m_cols; ++j ) // columns
            {
                if (T(int16_t( (*this)(i,j))) != T( (*this)(i,j)) ){
                    printf("[ERROR] on cut to 16 bit. lost precision. %li -> %li !\n", (*this)(i,j), T(int16_t( (*this)(i,j))));
                    exit(0);
                }
                output( i, j ) = T(int16_t( (*this)(i,j)));
            }
        }
        return output;
    }

    dynamic_matrix<T> add( const dynamic_matrix<T> &other) const
    {
        if (this->m_cols != other.m_cols || this->m_lines != other.m_lines)        //assert (m_lines == other.lines() && m_cols == other.cols());
            printf("ADD ERROR: Dimensions mismatch! This: %lix%li, other: %lix%li\n",this->m_cols, this->m_lines, other.m_cols, other.m_lines);

        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );

        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for( auto j=0u; j<m_cols; ++j ) // columns
            {
                output( i, j ) = (*this)(i,j) + other(i,j);
            }
        }

//        printf("acc (*this):\n");
//        print();
        return output;
    }
    dynamic_matrix<T> operator+( const dynamic_matrix<T> &other) {
        return this->add(other);
    }


    dynamic_matrix<T> shift_r( const int &factor, bool floating = false ) const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );
        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for( auto j=0u; j<m_cols; ++j ) // columns
            {
                if (!floating)
                    output( i, j ) = T((*this)(i,j) >> factor);
                else
                    output( i, j ) = T((*this)(i,j) / pow(double(2), double(factor)));
            }
        }
        return output;
    }
    dynamic_matrix<T> operator>>(  const int &factor) {
        return this->shift_r(factor);
    }

    dynamic_matrix<T> pool_max( const unsigned int &stride = 2 ) const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        if (steps_cols % stride != 0 || steps_lines % stride != 0)
            printf_error("Pool in C Ref: input %i x %i is not divideable by pool size %i!\n", m_cols, m_lines, stride);

        dynamic_matrix<T> output( steps_lines/stride, steps_cols/stride );
        for( auto i=0u; i <m_lines; i+=stride ) // lines
        {
            for( auto j=0u; j<m_cols; j+=stride ) // columns
            {
                T a = (*this)(i,j);
                T b = (*this)(i+1,j);
                T c = (*this)(i,j+1);
                T d = (*this)(i+1,j+1);

                T e = a > b ? a : b;
                T f = c > d ? c : d;

                output( i/stride, j/stride ) = e > f ? e : f;
            }
        }
        return output;
    }

    dynamic_matrix<T> relu_rect() const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );
        for( auto i=0u; i <m_lines; i++ ) // lines
        {
            for( auto j=0u; j<m_cols; j++ ) // columns
            {
                output( i, j ) = ((*this)(i,j) > 0)? (*this)(i,j) : 0;
            }
        }
        return output;
    }

    dynamic_matrix<T> relu_leaky(bool use_float = false, double value = 0.1, int32_t fpf = 24) const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );
        for( auto i=0u; i <m_lines; i++ ) // lines
        {
            for( auto j=0u; j<m_cols; j++ ) // columns
            {
                if (use_float){
                    output( i, j ) = ((*this)(i,j) > 0)? (*this)(i,j) : (*this)(i,j) * value;
                } else {
                    if (value != 0.1)
                        printf("leaky relu only for value 0.1 in FP implemented! [using 0.1]");

                    // Perfom LEAKY RELU
                    uint64_t val = (*this)(i, j) * T(VPRO_CONST::leak[fpf]);
                    val = (val >> fpf); // take upper part of result
                    val = *__24to64signed(val);
                    output(i, j) = ((*this)(i, j) > 0) ? (*this)(i, j) : T(val);
                }
            }
        }
        return output;
    }

    dynamic_matrix<T> relu_6(int32_t value_6 = 6) const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );
        for( auto i=0u; i <m_lines; i++ ) // lines
        {
            for( auto j=0u; j<m_cols; j++ ) // columns
            {
                output( i, j ) = std::max(T(0), std::min(T(value_6), (*this)(i,j)));
            }
        }
        return output;
    }

    dynamic_matrix<T> shift_l( const unsigned int &factor ) const
    {
        const auto steps_lines = m_lines;
        const auto steps_cols = m_cols;
        dynamic_matrix<T> output( steps_lines, steps_cols );
        for( auto i=0u; i <m_lines; ++i ) // lines
        {
            for( auto j=0u; j<m_cols; ++j ) // columns
            {
                output( i, j ) = T((*this)(i,j) << factor);
            }
        }
        return output;
    }
    dynamic_matrix<T> operator<<(  const int &factor) {
        return this->shift_l(factor);
    }


    dynamic_matrix multiply( const dynamic_matrix<T>& other ) const
    {
        dynamic_matrix output( m_lines, other.m_cols );

        for( auto m=0u; m<m_lines; ++m )
            for( auto k=0u; k<other.m_cols; ++k )
                for( auto n=0u; n<m_cols; ++n)
                {
                    output(m,k) += (*this)(m,n) * other(n,k);
                }

        return output;
    }
    dynamic_matrix<T> operator*( const dynamic_matrix<T>& other) {
        return this->multiply(other);
    }

    void print() const {
        printf("Matrix of size (%li x %li)\n", m_cols, m_lines);

        for( auto m=0u; m<fmin(10,float(m_lines)); ++m ) {
            printf("\n  ");
            for (auto n = 0u; n < fmin(10,float(m_cols)); ++n)
                printf("%7i, ", int((*this)(m,n)));
            if (m_cols > 10) printf("...");
        }
        if (m_lines > 10) printf("\n\t...");
        printf("\n  ");
    }

};





#endif //VPRO_TUTORIAL_CNN_CNN_C_REF_H
