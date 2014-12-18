/* minimum spanning tree .cpp

   ver: 0.2

   by PHC, June, 2002
   updated by Hanchuan Peng, Nov, 19, 2004. Add an optional root node

  */

#include "graph.h"

#include "graphsupport.h"

//global variables

const int ColorWhite = 0;
const int ColorGrey = 1;
const int ColorBlack = 2;
const int ColorRed = 3;

long extractWhiteMin(BYTE * colorQ, double ** wei, long len);
class PrimMSTClass //the Prim's MST algorithm
{
public:
  long nnode;

  double * adjMatrix1d,  ** adjMatrix2d;

  BYTE * nodeColor; //decide if a node has been visited or not
  double * nodeKey; 
  long * nodeParent; 
  long * nodeDetectTime;
  long * nodeFinishTime;

  void dosearch(long r);//r -- root node
  int allocatememory(long nodenum);
  void delocatememory();

  int b_disp;

  PrimMSTClass() {
    nnode = 0;
    adjMatrix1d = 0;
    adjMatrix2d = 0;
    nodeColor = 0;
    nodeKey = 0;
    nodeParent = 0;
    nodeDetectTime = 0;
    nodeFinishTime = 0;
    b_disp = 0;
  }
  ~PrimMSTClass() {
    delocatememory();
    nnode = 0;
  }
};

long extractWhiteMin(BYTE * colorQ, double ** wei, long len)
{
  double min=100000000;
  long idxmin=-1;
  long b_min0 = 0;
  long i,j;
  for (i=0;i<len;i++) {
    if (colorQ[i]==ColorBlack) {
      for (j=0;j<len;j++) {
        if (colorQ[j]==ColorWhite && wei[i][j]>0) {
          if (b_min0==0) {
            b_min0 = 1;
            min = wei[i][j];
            idxmin = j;
          }
          else { //if (b_min0==1)
            if (min>wei[i][j]) {
              min = wei[i][j];
              idxmin = j;
            }
          }
        }
      }
    }
  }
  if (b_min0==0) {
    idxmin = -1;
  }
  return idxmin;
}
/*
long extractWhiteMin(long * priorityQ, BYTE * colorQ, long len)
{
  long min=100000000,imin=0;
  long b_min0 = 0;
  for (long i=0;i<len;i++) {
    if (colorQ[i]==ColorWhite) {
      if (b_min0==0) {
        b_min0 = 1;
        min = priorityQ[i];
        imin = i;
      }
      else { //if (b_min0==1)
        if (min>priorityQ[i]) {
          min = priorityQ[i];
          imin = i;
        }
      }
    }
  }
  if (b_min0==1) {
    //printf("%d ",min);
    colorQ[imin] = ColorBlack; //so will not visit this node any more
    return min;
  }
  else {
    min = 100000000;
    return min;
  }
}
*/
void PrimMSTClass::dosearch(long r) //r -- root node
{
  if (nnode<=0 || !adjMatrix1d || !adjMatrix2d) {
    printf("The input data has not been set yet!\n");
    return;
  }

  //make r a reasonable index
  
  r = (r<0)?0:r;
  r = (r>nnode)?nnode-1:r;

  long i,j;
  long * localQueue_node = 0;
  long time;
  long nleftnode;

  localQueue_node = new long [nnode];
  if (!localQueue_node) {
    printf("Fail to do: long * localQueue_node = new long [nnode];\n");
    goto Label_FreeMemory_Return;
  }

  // initialization

  for (i=0;i<nnode;i++) {
    localQueue_node[i] = i;
    nodeColor[i] = ColorWhite;
    nodeKey[i] = 10000;//revise a larger num later
    nodeParent[i] = -1;
    nodeDetectTime[i] = -1;
    nodeFinishTime[i] = -1;
  }
  time = 0;

  nodeKey[r] = 0;
  nodeParent[r] = -1;
  
  // begin BFS loop

  nleftnode = nnode;
  while (nleftnode>0) {
    i = extractWhiteMin(nodeColor,adjMatrix2d,nnode);
    if (i==-1) { //for the first node
      i = r;
    }
    nodeDetectTime[i] = ++time;

    if (b_disp) {
      printf("time=%i curnode=%i \n",time,i+1);
    }
    
    for (j=0;j<nnode;j++) {
      if (adjMatrix2d[i][j]>0 &&
          nodeColor[j]==ColorWhite && 
          adjMatrix2d[i][j]<nodeKey[j]) {
            nodeParent[j] = i+1; //add 1 for the matlab convention
            nodeKey[j] = adjMatrix2d[i][j];
          }
    }
    
    nodeColor[i] = ColorBlack;
    nodeFinishTime[i] = ++time;
    nleftnode--;
  }

 Label_FreeMemory_Return:
  
  if (localQueue_node) delete []localQueue_node;

  return;
}//%================ end of MST_dosearch()=================

int PrimMSTClass::allocatememory(long nodenum) 
{
  if (nodenum>0) {
    nnode = nodenum;
  }

  int b_memory = 1;
  if (nnode>0) {
    delocatememory();
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeColor,nnode));
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeDetectTime,nnode));
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeFinishTime,nnode));
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeKey,nnode));
    b_memory = b_memory && (new2dArrayMatlabProtocal(adjMatrix2d,adjMatrix1d,nnode,nnode));
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeParent,nnode));
  }
  if (!b_memory) {
    delocatememory();
    return 0; //fail
  }
  else
    return 1; //success
}
void PrimMSTClass::delocatememory() 
{
  delete1dArrayMatlabProtocal(nodeColor);
  delete1dArrayMatlabProtocal(nodeDetectTime);
  delete1dArrayMatlabProtocal(nodeFinishTime);
  delete1dArrayMatlabProtocal(nodeKey);
  delete1dArrayMatlabProtocal(nodeParent);
  delete2dArrayMatlabProtocal(adjMatrix2d,adjMatrix1d);
}

//main program

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  //check data 
  
  if(nrhs < 1 || nrhs>2) {
    printf("Usage [node_attribute] = mst_prim(adjArray2d, rootnode).\n");
    printf("node_attr = [color,key,parent,dtime,ftime].\n");
    printf("If unspecified (between 1 to N), the root node is the first node.\n");
    mexErrMsgTxt("No input para specified. Exit.");
  }
  if(nlhs > 1)
    mexErrMsgTxt("Too many output arguments <labelled_rgn>.");

  //copy data

  void *inimg = (void *)mxGetData(prhs[0]);
  const long totalpxlnum = mxGetNumberOfElements(prhs[0]);
  mxClassID inimgtype = mxGetClassID(prhs[0]);
  long cwid = (long)mxGetN(prhs[0]);
  long chei = (long)mxGetM(prhs[0]);
  if(cwid!=chei) {
    mexErrMsgTxt("the connectivity matrix has to be square!");
  }
  
  //====================================by PHC, 041119=========
  long rootnode=0; //default
  if (nrhs==2)
  {
    rootnode = (long)*mxGetPr(prhs[1]) - 1;
    rootnode = (rootnode<0)?0:rootnode;
    rootnode = (rootnode>cwid-1)?(cwid-1):rootnode;
    printf("The root node is set as %dth node.\n", rootnode+1);
  }
  //===========================================================

  PrimMSTClass * pMST = new PrimMSTClass;
  if (!pMST)
    {mexErrMsgTxt("Fail to allocate memory for MSTClass().");}
  pMST->nnode = chei;
  pMST->allocatememory(pMST->nnode);

  double diffmaxmin;
  double minlevel,maxlevel;
  switch(inimgtype) {
  case mxINT8_CLASS: 
    copyvecdata_T2D((BYTE *)inimg,totalpxlnum,pMST->adjMatrix1d,
		    diffmaxmin,minlevel,maxlevel); 
    break;
  case mxUINT8_CLASS: 
    copyvecdata_T2D((UBYTE *)inimg,totalpxlnum,pMST->adjMatrix1d,
		    diffmaxmin,minlevel,maxlevel); 
    break;
  case mxDOUBLE_CLASS: 
    copyvecdata_T2D((double *)inimg,totalpxlnum,pMST->adjMatrix1d,
		    diffmaxmin,minlevel,maxlevel); 
    break;
  default:
    mexErrMsgTxt("Unsupported data type.");
    break;
  } 

  //printf("min=%i max=%i\n",minlevel,maxlevel);

  //begin computation
  pMST->dosearch(rootnode); //set root as the first node

  //create the Matlab structure array

  plhs[0] = mxCreateDoubleMatrix(pMST->nnode,5,mxREAL);
  double * out_nodeColor = mxGetPr(plhs[0]);
  double * out_nodeKey = out_nodeColor + pMST->nnode;
  double * out_nodeParent = out_nodeKey + pMST->nnode;
  double * out_nodeDetectTime = out_nodeParent + pMST->nnode;
  double * out_nodeFinishTime = out_nodeDetectTime + pMST->nnode;
  for (long i=0;i<pMST->nnode;i++) {
    out_nodeColor[i] = pMST->nodeColor[i];
    out_nodeKey[i] = pMST->nodeKey[i];
    out_nodeParent[i] = pMST->nodeParent[i];
    out_nodeDetectTime[i] = pMST->nodeDetectTime[i];
    out_nodeFinishTime[i] = pMST->nodeFinishTime[i];
  }

  //free memory and return

  if (pMST) {delete pMST;}
  return;
}

