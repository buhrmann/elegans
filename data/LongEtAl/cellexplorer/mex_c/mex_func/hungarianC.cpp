/*
 compilation for Matlab:
 mex -c mymatrix.cpp
 mex -c munkres.cpp 
 mex hungarianC.cpp
 */
// By Fuhui Long
//
// 08/02/2007



#include "mex.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <iostream>
#include <cstdlib>
#include <ctime>

// // #include "munkres.cpp"
#include "mymatrix.cpp"
#include "munkres.cpp"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{


    int i,j;
    //check input/output number
    if (nrhs!=1) mexErrMsgTxt(" The number of input arguments should be 1!");
    if (nlhs!=1)  mexErrMsgTxt("The number of output arugments should be 1");

    //check input data type  
    if ((mxGetNumberOfDimensions(prhs[0]) != 2) | (!mxIsDouble(prhs[0])))  
        mexErrMsgTxt("The input argument must be a 2 dimensional matrix of DOUBLE type.");     
    
    // Process input parameters
    
//     Matrix<double> *d1d = (Matrix<double> *)mxGetPr(prhs[0]);    

    double *d1d = (double *)mxGetPr(prhs[0]);       
    long col = mxGetM(prhs[0]);
    long row = mxGetN(prhs[0]);
        
/*    Matrix<double> d2d(row, col) = new Matrix<double> * [row];

    if (!d2d)
        mexErrMsgTxt("Fail to allocate memory.");
    else 
    {
    for (i=0;i<row;i++)
      d2d[i] = d1d + i*col;
    }*/
  

	Matrix<double> d2d(row, col);

    long cnt = 0;
 
//	srandom(time(NULL)); // Seed random number generator.
    
	// Initialize matrix with random values.
	for ( i = 0 ; i < row ; i++ ) {
		for ( j = 0 ; j < col ; j++ ) {
 			d2d(i,j) = d1d[cnt];
            cnt++;
//			d2d(i,j) = (double)random();
            
		}
	}

// 	// Display begin matrix state.
// 	for ( i = 0 ; i < row ; i++ ) {
// 		for ( j = 0 ; j < col ; j++ ) {
// 			std::cout.width(2);
// 			std::cout << d2d(i,j) << ",";
// 		}
// 		std::cout << std::endl;
// 	}
// 	std::cout << std::endl;    
        

    // call hungarian function
//     m.solve(**d2d);
    Munkres m;
    m.solve(d2d);
    
    // generate output
    plhs[0] = mxCreateDoubleMatrix(col,row, mxREAL);
//     Matrix<double> *matching = (Matrix<double> *) mxGetPr(plhs[0]);
    double *matching = (double *) mxGetPr(plhs[0]);
    
 //   double **matching2d = new double * [col];
    
    cnt = 0;

    for (i=0; i<row; i++)
    {
        for (j=0; j<col; j++)
        {
//             matching[cnt] = d1d[cnt];
            matching[cnt] = d2d(i,j);
            
            cnt++;
        }
    }    
    
//   if (d2d)
//   {
//     delete [] d2d;
//     d2d = 0;
//   } 

    return;
 
}