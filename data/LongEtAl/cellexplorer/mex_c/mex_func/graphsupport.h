/* graphsupport.cpp -- a few supporting function for the graph algorithms
   ver: 0.1
   by PHC, June, 2002
  */


#ifndef _GRAPH_SUPPORT_FUNCTIONS_
#define _GRAPH_SUPPORT_FUNCTIONS_

#include "graph.h"

//global variables

template <class T> int new2dArrayMatlabProtocal(T ** & img2d,T * & img1d,long imghei,long imgwid);
template <class T> void delete2dArrayMatlabProtocal(T ** & img2d,T * & img1d);

template <class T> int new1dArrayMatlabProtocal(T * & img1d,long nodenum);
template <class T> void delete1dArrayMatlabProtocal(T * & img1d);

//generating an UBYTE image for any input image type
template <class T> void copyvecdata_T2UB(T * srcdata, 
					 long len, 
					 UBYTE * desdata, 
					 int& nstate, 
					 UBYTE &minn, 
					 UBYTE &maxx);
template <class T> void copyvecdata_T2D(T * srcdata, 
					long len, 
					double * desdata, 
					double &nstate, 
					double &minn, 
					double &maxx);

//==================definition=============================

template <class T> void copyvecdata_T2UB(T * srcdata, 
					 long len, 
					 UBYTE * desdata, 
					 int& nstate, 
					 UBYTE &minn, 
					 UBYTE &maxx)
{
  if(!srcdata || !desdata)
  {
    printf("NULL points in copyvecdata()!\n");
    return;
  } 

  long i;

  //note: originally I added 0.5 before rounding, however seems the negative numbers and 
  //      positive numbers are all rounded towarded 0; hence int(-1+0.5)=0 and int(1+0.5)=1;
  //      This is unwanted because I need the above to be -1 and 1.
  // for this reason I just round with 0.5 adjustment for positive and negative differently

  //copy data
  if (srcdata[0]>0)
    maxx = minn = int(srcdata[0]+0.5);
  else
    maxx = minn = int(srcdata[0]-0.5);

  int tmp;
  double tmp1;
  for (i=0;i<len;i++)
  {
    tmp1 = double(srcdata[i]);
    tmp = (tmp1>0)?(int)(tmp1+0.5):(int)(tmp1-0.5);//round to integers
    minn = (minn<tmp)?minn:tmp;
    maxx = (maxx>tmp)?maxx:tmp;
    desdata[i] = (UBYTE)tmp;
    //    printf("%i ",desdata[i]);
  }
  maxx = (UBYTE)maxx;
  minn = (UBYTE)minn;
  //printf("\n");

  /*
  //make the vector data begin from 0 (i.e. 1st state)
  for (i=0;i<len;i++)
  {
    desdata[i] -= minn;
  }
  */

  //return the #state
  nstate = (maxx-minn+1);

  return;
}

template <class T> void copyvecdata_T2D(T * srcdata, 
					long len, 
					double * desdata, 
					double &nstate, 
					double &minn, 
					double &maxx)
{
  if(!srcdata || !desdata)
  {
    printf("NULL points in copyvecdata_D2T()!\n");
    return;
  } 

  long i;

  //note: originally I added 0.5 before rounding, however seems the negative numbers and 
  //      positive numbers are all rounded towarded 0; hence int(-1+0.5)=0 and int(1+0.5)=1;
  //      This is unwanted because I need the above to be -1 and 1.
  // for this reason I just round with 0.5 adjustment for positive and negative differently

  //copy data
  maxx = minn = double(srcdata[0]);

  double tmp;
  for (i=0;i<len;i++)
  {
    tmp = double(srcdata[i]);
    minn = (minn<tmp)?minn:tmp;
    maxx = (maxx>tmp)?maxx:tmp;
    desdata[i] = tmp;
  }
  /*
  //make the vector data begin from 0 (i.e. 1st state)
  for (i=0;i<len;i++)
  {
    desdata[i] -= minn;
  }
  */

  //return the #state
  nstate = (maxx-minn);

  return;
}


//memory management

template <class T> int new2dArrayMatlabProtocal(T ** & img2d,T * & img1d,long imghei,long imgwid)
{
  long totalpxlnum = (long)imghei*imgwid;
  img1d = new T [totalpxlnum];
  img2d = new T * [(long)imgwid];
  
  if (!img1d || !img2d)
  {
    if (img1d) {delete img1d;img1d=0;}
    if (img2d) {delete img2d;img2d=0;}
    printf("Fail to allocate mem in newIntImage2dPairMatlabProtocal()!");
    return 0; //fail
  }

  long i;

  for (i=0;i<imgwid;i++) 
    {img2d[i] = img1d + i*imghei;}

  for (i=0;i<totalpxlnum;i++) 
    {img1d[i] = (T)0;}

  return 1; //succeed
}
template <class T> void delete2dArrayMatlabProtocal(T ** & img2d,T * & img1d)
{
  if (img1d) {delete img1d;img1d=0;}
  if (img2d) {delete img2d;img2d=0;}
}

template <class T> int new1dArrayMatlabProtocal(T * & img1d, long nnode)
{
  img1d = new T [nnode];
  if (!img1d) {
    printf("Fail to allocate mem in newIntImage2dPairMatlabProtocal()!");
    return 0; //fail
  }
  long i;
  for (i=0;i<nnode;i++) {img1d[i] = (T)0;}
  return 1; //succeed
}
template <class T> void delete1dArrayMatlabProtocal(T * & img1d)
{
  if (img1d) {delete img1d;img1d=0;}
}

template <class T> void printimg(T * img, long nnode)
{
  printf("\n--<beg\n");
  for(long inode=0;inode<nnode;inode++)
  {
    printf("%i ",int(img[inode]));
  }
  printf("\nend>--\n");
}

#endif //ifndef _GRAPH_SUPPORT_FUNCTIONS_
