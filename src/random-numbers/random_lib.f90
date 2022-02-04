MODULE m_random_number_library
! Inspired from: http://www.johndcook.com/julia_rng.html
! Original author in julia : John D Cook
! coded : Sukhbinder in fortran
! Date : 28th Feb 2012
!
! in order of appearance
! Non uniform random Number Generators in Fortran
! Random Sample from normal (Gaussian) distribution
! Random smaple from an exponential distribution
! Return a random sample from a gamma distribution
! return a random sample from an inverse gamma random variable
! return a sample from a Weibull distribution
! return a random sample from a Cauchy distribution
! return a random sample from a Student t distribution
! return a random sample from a Laplace distribution
! return a random sample from a log-normal distribution
! return a random sample from a beta distribution
!
!
!
! Non uniform random Number Generators in Fortran
!
use m_constants, only : pi
use, intrinsic  ::  ISO_FORTRAN_ENV, only: error_unit, output_unit
use m_random_base
use m_io_files_utils
use m_io_utils
!implicit none

!private
!public :: julia_ran
!
!type,extends(ranbase) :: julia_ran
!    integer    :: random_type = 1
!  contains
!
!    procedure  :: init_seed
!    procedure  :: get_extract_list
!    procedure  :: get_list
!    procedure  :: destroy
!    procedure  :: read_option
!end type
!
CONTAINS
!
!subroutine read_option(this)
!    class(julia_ran),intent(inout)   :: this
!
!    integer :: io_in
!
!    io_in=open_file_read('input')
!    call get_parameter(io_in,'input','julia_type',this%random_type)
!    call close_file('input',io_in)
!
!
!
!end subroutine
!
!
!
!!!!! initialize and destroy
!subroutine init_seed(this)
!    class(julia_ran),intent(in)   :: this
!
!end subroutine
!
!subroutine destroy(this)
!    class(julia_ran),intent(in)   :: this
!
!end subroutine






FUNCTION rand_uniform(a,b) RESULT(c)
implicit none
real(kind=8) :: a,b,c,temp
CALL RANDOM_NUMBER(temp)
    c= a+temp*(b-a)
END FUNCTION

!
! Random Sample from normal (Gaussian) distribution
!
FUNCTION rand_normal(mean,stdev) RESULT(c)
implicit none
real(kind=8) :: mean,stdev,c,temp(2),r,theta
c=0.0d0
IF(stdev <= 0.0d0) THEN

  WRITE(output_unit,'(a)') "Standard Deviation must be +ve"
ELSE
  CALL RANDOM_NUMBER(temp)
  r=(-2.0d0*log(temp(1)))**0.5
  theta = 2.0d0*PI*temp(2)
  c= mean+stdev*r*sin(theta)
END IF
END FUNCTION

!
! Random smaple from an exponential distribution
!
FUNCTION rand_exponential(mean) RESULT(c)
implicit none
real(kind=8) :: mean,c,temp
c=0.0d0
IF (mean <= 0.0d0) THEN

   WRITE(output_unit,'(a)') "mean must be positive"
ELSE
   CALL RANDOM_NUMBER(temp)
   c=-mean*log(temp)
END IF
END FUNCTION

!
! Return a random sample from a gamma distribution
!
RECURSIVE FUNCTION rand_gamma(shape, SCALE) RESULT(ans)
implicit none
real(kind=8) SHAPE,scale,u,w,d,c,x,xsq,g,ans,v
IF (shape <= 0.0d0) THEN

   WRITE(output_unit,'(a)') "Shape PARAMETER must be positive"
END IF
IF (scale <= 0.0d0) THEN

   WRITE(output_unit,'(a)') "Scale PARAMETER must be positive"
END IF
!
! ## Implementation based on "A Simple Method for Generating Gamma Variables"
! ## by George Marsaglia and Wai Wan Tsang.
! ## ACM Transactions on Mathematical Software

! ## Vol 26, No 3, September 2000, pages 363-372.
!
IF (shape >= 1.0d0) THEN
   d = SHAPE - 1.0d0/3.0d0
   c = 1.0d0/(9.0d0*d)**0.5
   DO while (.true.)
      x = rand_normal(0.0d0, 1.0d0)
      v = 1.0 + c*x
      DO while (v <= 0.0d0)
         x = rand_normal(0.0d0, 1.0d0)
         v = 1.0d0 + c*x
      END DO

      v = v*v*v
      CALL RANDOM_NUMBER(u)
      xsq = x*x
      IF ((u < 1.0d0 -.0331d0*xsq*xsq) .OR.  &
         (log(u) < 0.5d0*xsq + d*(1.0d0 - v + log(v))) )then
         ans=scale*d*v
         RETURN
      END IF

   END DO
ELSE
   g = rand_gamma(shape+1.0d0, 1.0d0)
   CALL RANDOM_NUMBER(w)
   ans=scale*g*(w)**(1.0d0/shape)
   RETURN
END IF

END FUNCTION
!
! ## return a random sample from a chi square distribution
! ## with the specified degrees of freedom
!
FUNCTION rand_chi_square(dof) RESULT(ans)
implicit none
real(kind=8) ans,dof
ans=rand_gamma(0.5d0, 2.0d0*dof)
END FUNCTION

!
! ## return a random sample from an inverse gamma random variable
!
FUNCTION rand_inverse_gamma(shape, SCALE) RESULT(ans)
implicit none
real(kind=8) SHAPE,scale,ans

! ## If X is gamma(shape, scale) then
! ## 1/Y is inverse gamma(shape, 1/scale)
ans= 1.0d0 / rand_gamma(shape, 1.0d0 / SCALE)
END FUNCTION
!
!## return a sample from a Weibull distribution
!

FUNCTION rand_weibull(shape, SCALE) RESULT(ans)
implicit none
real(kind=8) SHAPE,scale,temp,ans
IF (shape <= 0.0d0) THEN

   WRITE(output_unit,'(a)') "Shape PARAMETER must be positive"
END IF
IF (scale <= 0.0d0) THEN

   WRITE(output_unit,'(a)') "Scale PARAMETER must be positive"
END IF
CALL RANDOM_NUMBER(temp)
ans= SCALE * (-log(temp))**(1.0 / SHAPE)
END FUNCTION

!
!## return a random sample from a Cauchy distribution
!
FUNCTION rand_cauchy(median, SCALE) RESULT(ans)
implicit none
real(kind=8) ans,median,scale,p

IF (scale <= 0.0d0) THEN

   WRITE(output_unit,'(a)') "Scale PARAMETER must be positive"
END IF
CALL RANDOM_NUMBER(p)
ans = median + SCALE*tan(PI*(p - 0.5))
END FUNCTION

!
!## return a random sample from a Student t distribution
!
FUNCTION rand_student_t(dof) RESULT(ans)
implicit none
real(kind=8) ans,dof,y1,y2
IF (dof <= 0.d0) THEN

   WRITE(output_unit,'(a)') "Degrees of freedom must be positive"
END IF
!
! ## See Seminumerical Algorithms by Knuth
y1 = rand_normal(0.0d0, 1.0d0)
y2 = rand_chi_square(dof)
ans= y1 / (y2 / DOf)**0.50d0
!

END FUNCTION

!
!## return a random sample from a Laplace distribution
!## The Laplace distribution is also known as the double exponential distribution.
!
FUNCTION rand_laplace(mean, SCALE)  RESULT(ans)
implicit none
real(kind=8) ans,mean,scale,u
IF (scale <= 0.0d0) THEN

   WRITE(output_unit,'(a)') "Scale PARAMETER must be positive"
END IF
CALL RANDOM_NUMBER(u)
IF (u < 0.5d0) THEN

   ans = mean + SCALE*log(2.0*u)
ELSE
   ans = mean - SCALE*log(2*(1-u))
END IF

END FUNCTION

!
! ## return a random sample from a log-normal distribution
!
FUNCTION rand_log_normal(mu, sigma) RESULT(ans)
real(kind=8) ans,mu,sigma
ans= EXP(rand_normal(mu, sigma))
END FUNCTION

!
! ## return a random sample from a beta distribution
!
FUNCTION rand_beta(a, b) RESULT(ans)
implicit none
real(kind=8) a,b,ans,u,v
IF ((a <= 0.0d0) .OR. (b <= 0.0d0)) THEN

   WRITE(output_unit,'(a)') "Beta PARAMETERs must be positive"
END IF

! ## There are more efficient methods for generating beta samples.
! ## However such methods are a little more efficient and much more complicated.
! ## For an explanation of why the following method works, see
! ## http://www.johndcook.com/distribution_chart.html#gamma_beta

u = rand_gamma(a, 1.0d0)
v = rand_gamma(b, 1.0d0)
ans = u / (u + v)
END FUNCTION

END MODULE m_random_number_library
