/*
  HandmadeMath.h v1.5.0
  
  This is a single header file with a bunch of useful functions for game and
  graphics math operations.
  
  =============================================================================
  
  You MUST
  
     #define HANDMADE_MATH_IMPLEMENTATION
     
  in EXACTLY one C or C++ file that includes this header, BEFORE the
  include, like this:
  
     #define HANDMADE_MATH_IMPLEMENTATION
     #include "HandmadeMath.h"
     
  All other files should just #include "HandmadeMath.h" without the #define.
  
  =============================================================================
  
  To disable SSE intrinsics, you MUST
  
  #define HANDMADE_MATH_NO_SSE
  
  in EXACTLY one C or C++ file that includes this header, BEFORE the
  include, like this:
     
     #define HANDMADE_MATH_IMPLEMENTATION
     #define HANDMADE_MATH_NO_SSE
     #include "HandmadeMath.h"
  
  =============================================================================
  
  To use HandmadeMath without the CRT, you MUST 
  
     #define HMM_SINF MySinF
     #define HMM_COSF MyCosF
     #define HMM_TANF MyTanF
     #define HMM_SQRTF MySqrtF
     #define HMM_EXPF MyExpF
     #define HMM_LOGF MyLogF
     #define HMM_ACOSF MyACosF
     #define HMM_ATANF MyATanF
     #define HMM_ATAN2F MYATan2F
     
  Provide your own implementations of SinF, CosF, TanF, ACosF, ATanF, ATan2F, 
  ExpF, and LogF in EXACTLY one C or C++ file that includes this header,
  BEFORE the include, like this:     
  
     #define HMM_SINF MySinF
     #define HMM_COSF MyCosF
     #define HMM_TANF MyTanF
     #define HMM_SQRTF MySqrtF
     #define HMM_EXPF MyExpF
     #define HMM_LOGF MyLogF
     #define HMM_ACOSF MyACosF
     #define HMM_ATANF MyATanF
     #define HMM_ATAN2F MyATan2F
     #define HANDMADE_MATH_IMPLEMENTATION
     #include "HandmadeMath.h"
     
  If you do not define all of these, HandmadeMath.h will use the
  versions of these functions that are provided by the CRT.
  
  =============================================================================
  
  Version History:
      0.2 (*) Updated documentation
          (*) Better C compliance
          (*) Prefix all handmade math functions 
          (*) Better operator overloading
      0.2a
          (*) Prefixed Macros
      0.2b
          (*) Disabled warning 4201 on MSVC as it is legal is C11
          (*) Removed the f at the end of HMM_PI to get 64bit precision
      0.3
          (*) Added +=, -=, *=, /= for hmm_vec2, hmm_vec3, hmm_vec4
      0.4
          (*) SSE Optimized HMM_SqrtF
          (*) SSE Optimized HMM_RSqrtF
          (*) Removed CRT
      0.5
          (*) Added scalar multiplication and division for vectors
              and matrices
          (*) Added matrix subtraction and += for hmm_mat4
          (*) Reconciled all headers and implementations
          (*) Tidied up, and filled in a few missing operators
      0.5.1
          (*) Ensured column-major order for matrices throughout
          (*) Fixed HMM_Translate producing row-major matrices
      0.5.2
          (*) Fixed SSE code in HMM_SqrtF
          (*) Fixed SSE code in HMM_RSqrtF
      0.6
          (*) Added Unit testing
          (*) Made HMM_Power faster
          (*) Fixed possible efficiency problem with HMM_Normalize 
          (*) RENAMED HMM_LengthSquareRoot to HMM_LengthSquared
          (*) RENAMED HMM_RSqrtF to HMM_RSquareRootF
          (*) RENAMED HMM_SqrtF to HMM_SquareRootF
          (*) REMOVED Inner function (user should use Dot now)
          (*) REMOVED HMM_FastInverseSquareRoot function declaration
      0.7 
          (*) REMOVED HMM_LengthSquared in HANDMADE_MATH_IMPLEMENTATION (should
              use HMM_LengthSquaredVec3, or HANDMADE_MATH_CPP_MODE for function
              overloaded version)
          (*) REMOVED HMM_Length in HANDMADE_MATH_IMPLEMENTATION (should use
              HMM_LengthVec3, HANDMADE_MATH_CPP_MODE for function
              overloaded version)
          (*) REMOVED HMM_Normalize in HANDMADE_MATH_IMPLEMENTATION (should use
              HMM_NormalizeVec3, or HANDMADE_MATH_CPP_MODE for function
              overloaded version)
          (*) Added HMM_LengthSquaredVec2
          (*) Added HMM_LengthSquaredVec4
          (*) Addd HMM_LengthVec2
          (*) Added HMM_LengthVec4
          (*) Added HMM_NormalizeVec2
          (*) Added HMM_NormalizeVec4
     1.0
          (*) Lots of testing!
     1.1
          (*) Quaternion support
          (*) Added type hmm_quaternion
          (*) Added HMM_Quaternion
          (*) Added HMM_QuaternionV4
          (*) Added HMM_AddQuaternion
          (*) Added HMM_SubtractQuaternion
          (*) Added HMM_MultiplyQuaternion
          (*) Added HMM_MultiplyQuaternionF
          (*) Added HMM_DivideQuaternionF
          (*) Added HMM_InverseQuaternion
          (*) Added HMM_DotQuaternion
          (*) Added HMM_NormalizeQuaternion
          (*) Added HMM_Slerp
          (*) Added HMM_QuaternionToMat4
          (*) Added HMM_QuaternionFromAxisAngle
     1.1.1
          (*) Resolved compiler warnings on gcc and g++
     1.1.2
          (*) Fixed invalid HMMDEF's in the function definitions
     1.1.3
          (*) Fixed compile error in C mode
     1.1.4
          (*) Fixed SSE being included on platforms that don't support it
          (*) Fixed divide-by-zero errors when normalizing zero vectors.
     1.1.5
          (*) Add Width and Height to HMM_Vec2
          (*) Made it so you can supply your own SqrtF 
     1.2.0
          (*) Added equality functions for HMM_Vec2, HMM_Vec3, and HMM_Vec4.
              (*) Added HMM_EqualsVec2, HMM_EqualsVec3, and HMM_EqualsVec4
              (*) Added C++ overloaded HMM_Equals for all three
              (*) Added C++ == and != operators for all three
          (*) SSE'd HMM_MultiplyMat4 (this is _WAY_ faster)
          (*) SSE'd HMM_Transpose
     1.3.0
          (*) Remove need to #define HANDMADE_MATH_CPP_MODE
     1.4.0
          (*) Fixed bug when using HandmadeMath in C mode
          (*) SSEd all vec4 operations          
          (*) Removed all zero-ing
     1.5.0
          (*) Changed internal structure for better performance and inlining.
          (*) As a result, HANDMADE_MATH_NO_INLINE has been removed and no
              longer has any effect.
          
          
  LICENSE
  
  This software is in the public domain. Where that dedication is not
  recognized, you are granted a perpetual, irrevocable license to copy,
  distribute, and modify this file as you see fit.
  
  CREDITS
  
  Written by Zakary Strange (zak@strangedev.net && @strangezak)
  
  Functionality:
   Matt Mascarenhas (@miblo_)
   Aleph
   FieryDrake (@fierydrake)
   Gingerbill (@TheGingerBill)
   Ben Visness (@bvisness) 
   Trinton Bullard (@Peliex_Dev)
   
  Fixes:
   Jeroen van Rijn (@J_vanRijn)
   Kiljacken (@Kiljacken)
   Insofaras (@insofaras)
   Daniel Gibson (@DanielGibson)
*/
import 'dart:math';
import 'dart:typed_data';

/*
 * Utility functions
 */
double HMM_ToRadians(double Degrees) {
    return Degrees * (pi / 180.0);
}

double HMM_DotVec3(Float32List VecOne, Float32List VecTwo) =>
    (VecOne[0] * VecTwo[0]) + (VecOne[1] * VecTwo[1]) + (VecOne[2] * VecTwo[2]);

double HMM_LengthSquaredVec3(Float32List A) => HMM_DotVec3(A, A);


double HMM_LengthVec3(Float32List A) => sqrt(HMM_LengthSquaredVec3(A));


Float32List HMM_Mat4d(double Diagonal)
{
    Float32List Result = Float32List(16);
    
    Result[0 * 4 + 0] = Diagonal;
    Result[1 * 4 + 1] = Diagonal;
    Result[2 * 4 + 2] = Diagonal;
    Result[3 * 4 + 3] = Diagonal;

    return (Result);
}

Float32List HMM_NormalizeVec3(Float32List A)
{
    Float32List Result = Float32List(3);

    double VectorLength = HMM_LengthVec3(A);
    
    /* NOTE(kiljacken): We need a zero check to not divide-by-zero */
    if (VectorLength != 0.0) {
        Result[0] = A[0] * (1.0 / VectorLength);
        Result[1] = A[1] * (1.0 / VectorLength);
        Result[2] = A[2] * (1.0 / VectorLength);
    }
    
    return (Result);
}


/*
 * Common graphics transformations
 */


Float32List HMM_Orthographic(double Left, double Right, double Bottom, double Top, double Near, double Far)
{
  Float32List Result = Float32List(16);

  Result[0 * 4 + 0] = 2.0 / (Right - Left);
  Result[1 * 4 + 1] = 2.0 / (Top - Bottom);
  Result[2 * 4 + 2] = 2.0 / (Near - Far);
  Result[3 * 4 + 3] = 1.0;

  Result[3 * 4 + 0] = (Left + Right) / (Left - Right);
  Result[3 * 4 + 1] = (Bottom + Top) / (Bottom - Top);
  Result[3 * 4 + 2] = (Far + Near) / (Near - Far);

  return (Result);
}

Float32List HMM_Translate(Float32List Translation) {
  assert(Translation.length == 3);

  Float32List Result = HMM_Mat4d(1.0);

  Result[3 * 4 + 0] = Translation[0];
  Result[3 * 4 + 1] = Translation[1];
  Result[3 * 4 + 2] = Translation[2];

  return (Result);
}

Float32List HMM_Rotate(double Angle, Float32List Axis) {
    Float32List Result = HMM_Mat4d(1.0);
    
    Axis = HMM_NormalizeVec3(Axis);
    
    double SinTheta = sin(HMM_ToRadians(Angle));
    double CosTheta = cos(HMM_ToRadians(Angle));
    double CosValue = 1.0 - CosTheta;
    
    Result[0 * 4 + 0] = (Axis[0] * Axis[0] * CosValue) + CosTheta;
    Result[0 * 4 + 1] = (Axis[0] * Axis[1] * CosValue) + (Axis[2] * SinTheta);
    Result[0 * 4 + 2] = (Axis[0] * Axis[2] * CosValue) - (Axis[1] * SinTheta);
    
    Result[1 * 4 + 0] = (Axis[1] * Axis[0] * CosValue) - (Axis[2] * SinTheta);
    Result[1 * 4 + 1] = (Axis[1] * Axis[1] * CosValue) + CosTheta;
    Result[1 * 4 + 2] = (Axis[1] * Axis[2] * CosValue) + (Axis[0] * SinTheta);
    
    Result[2 * 4 + 0] = (Axis[2] * Axis[0] * CosValue) + (Axis[1] * SinTheta);
    Result[2 * 4 + 1] = (Axis[2] * Axis[1] * CosValue) - (Axis[0] * SinTheta);
    Result[2 * 4 + 2] = (Axis[2] * Axis[2] * CosValue) + CosTheta;
    
    return Result;
}


Float32List HMM_MultiplyMat4(Float32List Left, Float32List Right) {
  assert(Left.length == 16);
  assert(Right.length == 16);
  Float32List Result = Float32List(16);

  int Columns;
  for(Columns = 0; Columns < 4; ++Columns)
  {
      int Rows;
      for(Rows = 0; Rows < 4; ++Rows)
      {
          double Sum = 0;
          int CurrentMatrice;
          for(CurrentMatrice = 0; CurrentMatrice < 4; ++CurrentMatrice)
          {
              Sum += Left[CurrentMatrice * 4 + Rows] * Right[Columns * 4 + CurrentMatrice];
          }

          Result[Columns * 4 + Rows] = Sum;
      }
  }

  return (Result);
}