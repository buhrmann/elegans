// Use the linear interpolation to find the cut-planes(lines) and then re-construct the stack as a straightened shape
//
//
// by Hanchuan Peng
// July 30, 2005
// Nov 09, 2006: add 2D image support


#include "../elementmexheader.h"



#include <stdio.h>
#include <math.h>
                                                                                                                                     
#define BYTE signed char
#define UBYTE unsigned char

#define PI 3.141592635

void myErrorMsg(const char *error_msg)
{
	mexErrMsgTxt(error_msg);
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  if(nrhs < 4 || nrhs>5)
    myErrorMsg("Usage out3dvol = straight_nearfill(in3dvol, bposx, bposy, alpha, OutWid).\n in3dvol -- a UINT8 type 3D volume.\n bposx, bopxy -- arrays of the x- and y- coordinates of the backbone points. alpha -- the cutplane's tangent direction at each backbone point. \n OutWid - diameter of the cut plane.\n");
  if(nlhs > 1)
    myErrorMsg("Usage out3dvol = straight_nearfill(in3dvol, bposx, bposy, alpha, OutWid).\n in3dvol -- a UINT8 type 3D volume.\n bposx, bopxy -- arrays of the x- and y- coordinates of the backbone points. alpha -- the cutplane's tangent direction at each backbone point. \n OutWid - diameter of the cut plane.\n");

  //check if parameters are correct

  long i,j,k;

  UBYTE * invol1d = (UBYTE *)mxGetPr(prhs[0]);
  
  const int ndim = mxGetNumberOfDimensions(prhs[0]);
  if (ndim!=3 && ndim!=2)
    myErrorMsg("The input must be a 3D volume or a 2D image (then z direction has only 1 slice).\n");  

  const int * dim = mxGetDimensions(prhs[0]);
  long nx = long(dim[0]);
  long ny = long(dim[1]);
  long nz = (ndim==3)? long(dim[2]) : 1; //061109


  double *bposx = (double *)mxGetPr(prhs[1]);
  long bposx_len = mxGetM(prhs[1]) * mxGetN(prhs[1]);
  
  double *bposy = (double *)mxGetPr(prhs[2]);
  long bposy_len = mxGetM(prhs[2]) * mxGetN(prhs[2]);

  double *alpha = (double *)mxGetPr(prhs[3]);
  long alpha_len = mxGetM(prhs[2]) * mxGetN(prhs[2]);

  if ((bposx_len!=bposy_len) || (bposx_len!=alpha_len) || (bposx_len<=0))
    myErrorMsg("The two position coordinate vectors must have the same number of elements. \n");

  

  long lenbp = bposx_len;

  //printf("%i %i %i\n", nx, ny, nz);

  for (i=0; i<lenbp; i++)
  {
	//bpx[i] = long(bposx[i]); 
	if (bposx[i]<0 || bposx[i]>=nx-1) myErrorMsg("Find illegal bposx coordinates out of range of the image.\n"); //060916 change to ">=nx-1", originally ">nx-1"
	//bpy[i] = long(bposy[i]); 
	if (bposy[i]<0 || bposy[i]>=ny-1) myErrorMsg("Find illegal bposy coordinates out of range of the image.\n"); //060916 change to ">=ny-1", originally ">ny-1"
	if (alpha[i]<-PI || alpha[i]>PI) myErrorMsg("Find illegal alpha (cutplane's tangent direction) out of range [-PI, PI].\n"); 
  }


  long Kwid = 0;
  Kwid = (nrhs>=5)? long(*(double *)mxGetPr(prhs[4])) : 160; //default width of a straightened worm is 160-pixel
  if (Kwid<=0) {Kwid=160;} // for illeagal Kwid, force it to be the default. 

  
  //==================== set up the input and output volume matrix =====================

  int outdims[3];
  outdims[0] = int(Kwid);
  outdims[1] = int(lenbp);
  outdims[2] = int(nz);
  plhs[0] = mxCreateNumericArray(3, outdims, mxUINT8_CLASS, mxREAL);
  if (!plhs[0])
      myErrorMsg("Fail to allocate memory for the output volume.\n");
  UBYTE * outvol1d = (UBYTE *)mxGetPr(plhs[0]);  

  UBYTE *** outvol3d = new UBYTE ** [nz];
  for (i=0;i<nz;i++) {
    outvol3d[i] = new UBYTE * [lenbp];
    for (j=0;j<lenbp;j++) {
      outvol3d[i][j] = outvol1d + i*Kwid*lenbp + j*Kwid;
    }
  }

  UBYTE *** invol3d = new UBYTE ** [nz];
  for (i=0;i<nz;i++) {
    invol3d[i] = new UBYTE * [ny];
    for (j=0;j<ny;j++) {
      invol3d[i][j] = invol1d + i*nx*ny + j*nx;
    }
  }

  int ptspace = 1; // default value
  


  //============ generate nearest interpolation ===================

  double base0 = 0;
  long Krad = 0;

  if (floor(Kwid/2)*2==Kwid)
  {
    Krad = (Kwid-1)/2;
    base0 = 0;
  }
  else
  {
    Krad = Kwid/2;
    base0 = ptspace/2;
  }


  for (j=0;j<lenbp; j++)
  {
    double curalpha = alpha[j];

	double ptminx = bposx[j] - cos(curalpha)*(base0+Krad*ptspace);
    double ptminy = bposy[j] - sin(curalpha)*(base0+Krad*ptspace);

    for (k=0; k<Kwid; k++)
    {
      double curpx = ptminx + cos(curalpha)*(k*ptspace);
	  double curpy = ptminy + sin(curalpha)*(k*ptspace);

	  if (curpx<0 || curpx>nx-1 || curpy<0 || curpy>ny-1)
	  {
  	    for (i=0;i<nz; i++)
		{
		  outvol3d[i][j][k] = (UBYTE)(0); //out of image and set as default
		}
		continue;
	  }

      long cpx0 = long(floor(curpx)), cpx1 = long(ceil(curpx));
      long cpy0 = long(floor(curpy)), cpy1 = long(ceil(curpy));

      double w0x0y = (cpx1-curpx)*(cpy1-curpy);
      double w0x1y = (cpx1-curpx)*(curpy-cpy0);
      double w1x0y = (curpx-cpx0)*(cpy1-curpy);
      double w1x1y = (curpx-cpx0)*(curpy-cpy0);

	  for (i=0;i<nz; i++)
	  {
		outvol3d[i][j][k] = (UBYTE)(w0x0y * double(invol3d[i][cpy0][cpx0]) + w0x1y * double(invol3d[i][cpy1][cpx0]) +
                                    w1x0y * double(invol3d[i][cpy0][cpx1]) + w1x1y * double(invol3d[i][cpy1][cpx1]));

	  }
	}
  }


  

  // ====free memory=============
  if (outvol3d) {
    for (i=0;i<nz;i++) {
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

