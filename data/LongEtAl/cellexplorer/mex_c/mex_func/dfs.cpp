/* depth_first_search.cpp

This version is a major upgrade of my previous DFS-related programs.
I use "goto" and my own stack in this program.

-- This is a graph searching algorithm based on a previous version of
	rgnfindgraph02.cpp

	a prog modified from the image region growing prog rgnfind2dc.cpp.1.2 to
	find the connected regions on a sparse-connected graph 
	(2d connectivity matrix)

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

class DFSClass //DepthFirstSearchClass
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
	
	DFSClass() {
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
	~DFSClass() {
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

void DFSClass::dosearch()
{
	if (nnode<=0 || !adjMatrix1d || !adjMatrix2d) {
		mexPrintf("The input data has not been set yet!\n");
		return;
	}
	
	long i,j,tmpi,tmpj;
	long * localStack_node_i = 0;
	long * localStack_node_j = 0;
	long stackIdx = 0;
	const long stackProtectLen = 128;
	long time;
	long curDCGLabel = 1;
	
	localStack_node_i = new long [nnode+2*stackProtectLen];
	if (!localStack_node_i) {
		mexPrintf("Fail to do: long * localStack_node_i = new long [nnode];\n");
		goto Label_FreeMemory_Return;
	}
	
	localStack_node_j = new long [nnode+2*stackProtectLen];
	if (!localStack_node_j) {
		mexPrintf("Fail to do: long * localStack_node_j = new long [nnode];\n");
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
	
	// begin DFS loop
	
	curDCGLabel = 1; //if the input graph is a symmetric undirected graph
					 //then this will return how many DCG in G
	for (i=0;i<nnode;i++) {
		
		if (nodeColor[i]==ColorWhite) {
			
			stackIdx = stackProtectLen; //protect both head and tail of stack
										//push stack
			localStack_node_i[stackIdx] = i; 
			localStack_node_j[stackIdx] = j = -1; 
			stackIdx++;
			if (stackIdx>nnode+stackProtectLen) {
				mexPrintf("The local stack is overflow idx=%i!!!\n",stackIdx);
				goto Label_FreeMemory_Return;
			}
			if (b_disp) {
				mexPrintf("push %i %i statckIdx = %i\n",i+1,j+1, stackIdx);
			}
			
Label_DFS_Visit:
				
			nodeColor[i] = ColorGrey;
			nodeLabel[i] = curDCGLabel;
			nodeDetectTime[i] = ++time;
			
			for (j=0;j<nnode;j++) {
				
Label_DFS_Pop:
				
				if (nodeColor[j]==ColorWhite && adjMatrix2d[j][i]!=0) {
					nodeParent[j] = i+1; //the Matlab convention
					
					//push stack
					localStack_node_i[stackIdx] = i; 
					localStack_node_j[stackIdx] = j; 
					stackIdx++;
					if (stackIdx>nnode+stackProtectLen) {
						mexPrintf("The local stack is overflow idx=%i i=%i j=%i nnode=%i!!!\n",stackIdx,i+1,j+1,nnode);
						for (tmpi=stackProtectLen;tmpi<=stackIdx;tmpi++)
							mexPrintf("stack pos [%i] i=%i j=%i\n",tmpi,i+1,j+1);
						goto Label_FreeMemory_Return;
					}
					if (b_disp) {
						mexPrintf("push i=%i j=%i statckIdx = %i\n",i+1,j+1, stackIdx);
					}
					
					//call procedure
					i = j; 
					goto Label_DFS_Visit;
				}
			}
			
			nodeColor[i] = ColorBlack;
			nodeFinishTime[i] = ++time;
			
			goto Label_DFS_Exit;
			
Label_DFS_Exit:
				
				if (stackIdx>stackProtectLen) {
					//pop stack
					stackIdx--; 
					i = localStack_node_i[stackIdx];
					j = localStack_node_j[stackIdx]; 
					if (stackIdx<stackProtectLen) {
						mexPrintf("The local stack is underflow!!!\n");
						goto Label_FreeMemory_Return;
					}
					if (b_disp) {
						mexPrintf("pop i=%i j=%i stackIdx = %i\n",i+1,j+1,stackIdx);
					}
					if (nodeColor[i]!=ColorBlack)
						goto Label_DFS_Pop;
					else
						goto Label_DFS_Exit;
				}
			
			curDCGLabel++;
		}
	}
	
Label_FreeMemory_Return:
		
		if (localStack_node_i) delete []localStack_node_i;
	if (localStack_node_j) delete []localStack_node_j;
	
	return;
}//%================ end of DFS_dosearch()=================

int DFSClass::allocatememory(long nodenum) 
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
void DFSClass::delocatememory() 
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
	
	DFSClass * pDFS = new DFSClass;
	if (!pDFS)
    {mexErrMsgTxt("Fail to allocate memory for DFSClass().");}
	pDFS->nnode = chei;
	pDFS->allocatememory(pDFS->nnode);
	
	int nstate;
	UBYTE minlevel,maxlevel;
	switch(inimgtype) {
		case mxINT8_CLASS: 
			copyvecdata((BYTE *)inimg,totalpxlnum,pDFS->adjMatrix1d,
						nstate,minlevel,maxlevel); 
			break;
		case mxUINT8_CLASS: 
			copyvecdata((UBYTE *)inimg,totalpxlnum,pDFS->adjMatrix1d,
						nstate,minlevel,maxlevel); 
			break;
		case mxDOUBLE_CLASS: 
			copyvecdata((double *)inimg,totalpxlnum,pDFS->adjMatrix1d,
						nstate,minlevel,maxlevel); 
			break;
		default:
			mexErrMsgTxt("Unsupported data type.");
			break;
	} 
	
	//printf("min=%i max=%i\n",minlevel,maxlevel);
	
	//begin computation
	pDFS->dosearch();
	
	//printf("then --> phcDebugRgnNum=%i phcDebugPosNum=%i\n",phcDebugRgnNum,phcDebugPosNum);
	
	//create the Matlab structure array
	
	plhs[0] = mxCreateDoubleMatrix(pDFS->nnode,5,mxREAL);
	double * out_nodeColor = mxGetPr(plhs[0]);
	double * out_nodeLabel = out_nodeColor + pDFS->nnode;
	double * out_nodeParent = out_nodeLabel + pDFS->nnode;
	double * out_nodeDetectTime = out_nodeParent + pDFS->nnode;
	double * out_nodeFinishTime = out_nodeDetectTime + pDFS->nnode;
	for (long i=0;i<pDFS->nnode;i++) {
		out_nodeColor[i] = pDFS->nodeColor[i];
		out_nodeLabel[i] = pDFS->nodeLabel[i];
		out_nodeParent[i] = pDFS->nodeParent[i];
		out_nodeDetectTime[i] = pDFS->nodeDetectTime[i];
		out_nodeFinishTime[i] = pDFS->nodeFinishTime[i];
	}
	
	//free memory and return
	
	if (pDFS) {delete pDFS;}
	return;
}

