// Reslice the slices in an image stack using the x,y,z resolution 
//
//
// by Hanchuan Peng
// May 27, 2006
// 2008-05-01. add a nearest neighbor interp method, so that an mask image can be procesed


#include "../elementmexheader.h"


//#include "c:\math\matlab6p1\extern\include\mex.h"
//#include "c:\math\matlab6p1\extern\include\matrix.h"


#include <stdio.h>
#include <math.h>
                                                                                                                                     
#define BYTE signed char
#define UBYTE unsigned char

#define PI 3.141592635

template <class T> T max(T a, T b)
{
    return (a>=b)?a:b;
}

template <class T> T min(T a, T b)
{
    return (a<=b)?a:b;
}

struct PixelPos
{
    double x, y;
};

void myErrorMsg(const char *error_msg)
{
	mexErrMsgTxt(error_msg);
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  if(nrhs != 3 && nrhs != 4)
    myErrorMsg("Usage [out3dvol] = reslice_Z(in3dvol, xy_rez, z_rez, b_method).\n in3dvol -- a UINT8 type 3D volume. b_method=0 (linear), 1 (nearest neighbor interp), others (set to linear)\n");
  if(nlhs > 1)
    myErrorMsg("Usage [out3dvol] = reslice_Z(in3dvol, xy_rez, z_rez, b_method).\n in3dvol -- a UINT8 type 3D volume. b_method=0 (linear), 1 (nearest neighbor interp), others (set to linear)\n");

  //check if parameters are correct
  
  int b_method=0;
  if (nrhs>=4) {b_method = int(*mxGetPr(prhs[3])); if (b_method!=1) b_method=0;}

  long i,j,k;

  UBYTE * invol1d = (UBYTE *)mxGetPr(prhs[0]);
  
  const int ndim = mxGetNumberOfDimensions(prhs[0]);
  if (ndim!=3)
    myErrorMsg("The input must be a 3D volume.\n");  

  //get image
  
  const int * dim = mxGetDimensions(prhs[0]);
  long nx = long(dim[0]);
  long ny = long(dim[1]);
  long nz = long(dim[2]);
  if (nx*ny*nz<=0)
    myErrorMsg("You have provided an illgeal stack which is empty or has other problem.\n");  

  //get angles
  
  double xy_rez = *((double *)mxGetPr(prhs[1]));
  if (xy_rez<=0)
    myErrorMsg("You have provided an illgeal xy resolution value which must > 0.\n");  
  
  double z_rez = *((double *)mxGetPr(prhs[2]));
  if (z_rez<=0)
    myErrorMsg("You have provided an illgeal z resolution value which must > 0.\n");  


  
  //==================== set up the input and output volume matrix =====================

  UBYTE *** invol3d = new UBYTE ** [nz];
  for (i=0;i<nz;i++) {
    invol3d[i] = new UBYTE * [ny];
    for (j=0;j<ny;j++) {
      invol3d[i][j] = invol1d + i*nx*ny + j*nx;
    }
  }


  long xlen_out = nx;
  long ylen_out = ny;
  long zlen_out = long(floor((double(nz-1) * z_rez)/xy_rez)) + 1; //if use ceil() then rish having no value at the border
  double z_rez_new = xy_rez;
  
  int outdims[3];
  outdims[0] = int(xlen_out);
  outdims[1] = int(ylen_out);
  outdims[2] = int(zlen_out);
  
  plhs[0] = mxCreateNumericArray(3, outdims, mxUINT8_CLASS, mxREAL);
  if (!plhs[0])
      myErrorMsg("Fail to allocate memory for the output volume.\n");
  UBYTE * outvol1d = (UBYTE *)mxGetPr(plhs[0]);  

  UBYTE *** outvol3d = new UBYTE ** [zlen_out];
  for (i=0;i<zlen_out;i++) {
    outvol3d[i] = new UBYTE * [ylen_out];
    for (j=0;j<ylen_out;j++) {
      outvol3d[i][j] = outvol1d + i*xlen_out*ylen_out + j*xlen_out;
    }
  }

  printf("#original slice=%d original rez=%6.5f -> #output slices=%d new rez=%6.5f\n", nz, z_rez, zlen_out, z_rez_new);
  //return;
  
  //============ generate linear interpolation ===================

  double my_eps=1e-8;

  if (b_method==1) //nearest neighbor interpolation
  {
	  for (i=0; i<zlen_out; i++)
	  {
		  double curpz = i*z_rez_new/z_rez;
		  long cpz0 = long(floor(curpz)), cpz1 = long(ceil(curpz));
		  
		  if (cpz0==cpz1)
		  {
			  for (j=0;j<ylen_out; j++)
			  {
				for (k=0; k<xlen_out; k++)
				{
					outvol3d[i][j][k] = invol3d[cpz0][j][k];
				}
			  }
		  }
		  else
		  {
			  double w0z = (cpz1-curpz);
			  double w1z = (curpz-cpz0);
			  if (w0z>=w1z) //note >= condition so that to handle the case of x2 zoom-in
			  {
				  for (j=0;j<ylen_out; j++)
				  {
					for (k=0; k<xlen_out; k++)
					{
						outvol3d[i][j][k] = invol3d[cpz0][j][k];
					}
				  }
			  }
			  else
			  {
				  for (j=0;j<ylen_out; j++)
				  {
					for (k=0; k<xlen_out; k++)
					{
						outvol3d[i][j][k] = invol3d[cpz1][j][k];
					}
				  }
			  }
		  }
	  }
  }
  else //linear interpolation
  {
	  for (i=0; i<zlen_out; i++)
	  {
		  double curpz = i*z_rez_new/z_rez;
		  long cpz0 = long(floor(curpz)), cpz1 = long(ceil(curpz));
		  
		  if (cpz0==cpz1)
		  {
			  for (j=0;j<ylen_out; j++)
			  {
				for (k=0; k<xlen_out; k++)
				{
					outvol3d[i][j][k] = invol3d[cpz0][j][k];
				}
			  }
		  }
		  else
		  {
			  double w0z = (cpz1-curpz);
			  double w1z = (curpz-cpz0);
			  for (j=0;j<ylen_out; j++)
			  {
				for (k=0; k<xlen_out; k++)
				{
					outvol3d[i][j][k] = (UBYTE)(w0z * double(invol3d[cpz0][j][k]) + w1z * double(invol3d[cpz1][j][k]));
				}
			  }
		  }
	  }
  }


  

  // ====free memory=============
  if (outvol3d) {
    for (i=0;i<zlen_out;i++) {
      if (outvol3d[i]) delete [] outvol3d[i];
    }
    delete [] outvol3d;
    outvol3d = 0;
  }

  if (invol3d) {
    for (i=0;i<nz;i++) {
      if (invol3d[i]) delete [] invol3d[i];
    }
    delete [] invol3d;
    invol3d = 0;
  }
  
 
  
  return;
}

