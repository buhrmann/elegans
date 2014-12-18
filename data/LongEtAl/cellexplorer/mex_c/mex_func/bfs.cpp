/* breadth_first_search.cpp

   ver: 0.2

   by PHC, June, 2002

  */

#include "graph.h"

//global variables

const int ColorWhite = 0;
const int ColorGrey = 1;
const int ColorBlack = 2;
const int ColorRed = 3;

template <class T> int new2dArrayMatlabProtocal(T ** & img2d,T * & img1d,long imghei,long imgwid);
template <class T> void delete2dArrayMatlabProtocal(T ** & img2d,T * & img1d);

template <class T> int new1dArrayMatlabProtocal(T * & img1d,long nodenum);
template <class T> void delete1dArrayMatlabProtocal(T * & img1d);

//generating an UBYTE image for any input image type
template <class T> void copyvecdata(T * srcdata, 
				    long len, 
				    UBYTE * desdata, 
				    int& nstate, 
				    UBYTE &minn, 
				    UBYTE &maxx);

class BFSClass //BreadthFirstSearchClass
{
public:
  long nnode;

  UBYTE * adjMatrix1d,  ** adjMatrix2d;

  BYTE * nodeColor; //decide if a node has been visited or not
  long * nodeLabel; //this will decide in which subgraph a node is in
  long * nodeParent; //for the DFS tree
  long * nodeDetectTime;
  long * nodeFinishTime;

  void dosearch();
  int allocatememory(long nodenum);
  void delocatememory();

  int b_disp;

  BFSClass() {
    nnode = 0;
    adjMatrix1d = 0;
    adjMatrix2d = 0;
    nodeColor = 0;
    nodeLabel = 0;
    nodeParent = 0;
    nodeDetectTime = 0;
    nodeFinishTime = 0;
    b_disp = 0;
  }
  ~BFSClass() {
    delocatememory();
    nnode = 0;
  }
};


//////===========================================

template <class T> void copyvecdata(T * srcdata, 
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

void BFSClass::dosearch()
{
  if (nnode<=0 || !adjMatrix1d || !adjMatrix2d) {
    printf("The input data has not been set yet!\n");
    return;
  }
  
  long i,j,iu; //,iv;
  long * localQueue_node = 0;
  long queueHead = 0;
  long queueTail = 0;
  const long queueProtectLen = 128;
  long time;
  long curDCGLabel = 1;

  localQueue_node = new long [nnode+2*queueProtectLen];
  if (!localQueue_node) {
    printf("Fail to do: long * localQueue_node = new long [nnode];\n");
    goto Label_FreeMemory_Return;
  }

  // initialization

  for (i=0;i<nnode;i++) {
    nodeColor[i] = ColorWhite;
    nodeLabel[i] = -1;
    nodeParent[i] = -1;
    nodeDetectTime[i] = -1;
    nodeFinishTime[i] = -1;
  }
  time = 0;
  
  // begin BFS loop

  curDCGLabel = 1; //if the input graph is a symmetric undirected graph
                   //then this will return how many DCG in G
  for (i=0;i<nnode;i++) {
    
    if (nodeColor[i]==ColorWhite) {

      queueHead = queueProtectLen; //protect both head and tail of queue
      queueTail = queueHead-1;

      nodeColor[i] = ColorGrey;
      nodeLabel[i] = curDCGLabel;
      nodeParent[i] = -1;
      nodeDetectTime[i] = ++time;

      //Enqueue
      queueTail++;
      localQueue_node[queueTail] = i; 
      if (queueTail>=nnode+queueProtectLen) {
	printf("The local queue is overflow!!!\n");
	goto Label_FreeMemory_Return;
      }
      if (b_disp) {
	printf("push %i\t queueHead = %i \tqueueTail = %i ===\n",i+1, queueHead, queueTail);
      }

      while (queueHead<=queueTail) {
	
	iu = localQueue_node[queueHead];

	for (j=0;j<nnode;j++) {

	  if (nodeColor[j]==ColorWhite && adjMatrix2d[j][iu]!=0) {
	    nodeColor[j] = ColorGrey;
	    nodeLabel[j] = curDCGLabel;
	    nodeParent[j] = iu+1; //the Matlab convention
	    nodeDetectTime[j] = nodeDetectTime[iu]+1;

	    //enqueue
	    queueTail++;
	    localQueue_node[queueTail] = j; 

	    if (queueTail>=nnode+queueProtectLen) {
	      printf("The local queue is overflow!!!\n");
	      goto Label_FreeMemory_Return;
	    }
	    if (b_disp) {
	      printf("push %i\t queueHead = %i \tqueueTail = %i\n",j+1,queueHead, queueTail);
	    }
	  }
	}

	queueHead++; //dequeue
	if (b_disp) {
	  printf("pop %i\t queueHead = %i \tqueueTail = %i\n",i+1, queueHead, queueTail);
	}
      
	nodeColor[iu] = ColorBlack;
	nodeFinishTime[iu] = ++time;
      }
      curDCGLabel++;
    }
  }

 Label_FreeMemory_Return:
  
  if (localQueue_node) delete []localQueue_node;

  return;
}//%================ end of DFS_dosearch()=================

int BFSClass::allocatememory(long nodenum) 
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
    b_memory = b_memory && (new1dArrayMatlabProtocal(nodeLabel,nnode));
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
void BFSClass::delocatememory() 
{
  delete1dArrayMatlabProtocal(nodeColor);
  delete1dArrayMatlabProtocal(nodeDetectTime);
  delete1dArrayMatlabProtocal(nodeFinishTime);
  delete1dArrayMatlabProtocal(nodeLabel);
  delete1dArrayMatlabProtocal(nodeParent);
  delete2dArrayMatlabProtocal(adjMatrix2d,adjMatrix1d);
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

//main program

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  //check data 
  
  if(nrhs < 1) {
    printf("Usage [node_attribute] = progname(adjArray2d).\n");
    printf("node_attr = [color,label,parent,dtime,ftime].\n");
    mexErrMsgTxt("No input para specified. Exit.");
  }
  if(nlhs > 1)
    mexErrMsgTxt("Too many output arguments <labelled_rgn>.");

  //copy data

  void *inimg = (void *)mxGetPr(prhs[0]);
  const long totalpxlnum = mxGetNumberOfElements(prhs[0]);
  mxClassID inimgtype = mxGetClassID(prhs[0]);
  long cwid = (long)mxGetN(prhs[0]);
  long chei = (long)mxGetM(prhs[0]);
  if(cwid!=chei) {
    mexErrMsgTxt("the connectivity matrix has to be square!");
  }

  BFSClass * pBFS = new BFSClass;
  if (!pBFS)
    {mexErrMsgTxt("Fail to allocate memory for DFSClass().");}
  pBFS->nnode = chei;
  pBFS->allocatememory(pBFS->nnode);

  int nstate;
  UBYTE minlevel,maxlevel;
  switch(inimgtype) {
  case mxINT8_CLASS: 
    copyvecdata((BYTE *)inimg,totalpxlnum,pBFS->adjMatrix1d,
		nstate,minlevel,maxlevel); 
    break;
  case mxUINT8_CLASS: 
    copyvecdata((UBYTE *)inimg,totalpxlnum,pBFS->adjMatrix1d,
		nstate,minlevel,maxlevel); 
    break;
  case mxDOUBLE_CLASS: 
    copyvecdata((double *)inimg,totalpxlnum,pBFS->adjMatrix1d,
		nstate,minlevel,maxlevel); 
    break;
  default:
    mexErrMsgTxt("Unsupported data type.");
    break;
  } 

  //printf("min=%i max=%i\n",minlevel,maxlevel);

  //begin computation
  pBFS->dosearch();

  //printf("then --> phcDebugRgnNum=%i phcDebugPosNum=%i\n",phcDebugRgnNum,phcDebugPosNum);

  //create the Matlab structure array

  plhs[0] = mxCreateDoubleMatrix(pBFS->nnode,5,mxREAL);
  double * out_nodeColor = mxGetPr(plhs[0]);
  double * out_nodeLabel = out_nodeColor + pBFS->nnode;
  double * out_nodeParent = out_nodeLabel + pBFS->nnode;
  double * out_nodeDetectTime = out_nodeParent + pBFS->nnode;
  double * out_nodeFinishTime = out_nodeDetectTime + pBFS->nnode;
  for (long i=0;i<pBFS->nnode;i++) {
    out_nodeColor[i] = pBFS->nodeColor[i];
    out_nodeLabel[i] = pBFS->nodeLabel[i];
    out_nodeParent[i] = pBFS->nodeParent[i];
    out_nodeDetectTime[i] = pBFS->nodeDetectTime[i];
    out_nodeFinishTime[i] = pBFS->nodeFinishTime[i];
  }

  //free memory and return

  if (pBFS) {delete pBFS;}
  return;
}

