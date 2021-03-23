module m_mode_construction_rank1_point
use m_mode_construction
use m_derived_types, only : lattice,number_different_order_parameters
implicit none
private
public F_mode_rank1_point

type, extends(F_mode) :: F_mode_rank1_point
    integer,private     :: order=0
    contains
    !necessary routines as defined by class
    procedure   :: get_mode   !subroutine which returns the mode 
    procedure   :: get_mode_exc
    procedure   :: mode_reduce

    procedure   :: copy
    procedure   :: bcast
    procedure   :: destroy
    procedure   :: is_same
    !local construction routine
    procedure   :: init_order
end type

contains

subroutine get_mode(this,lat,mode,tmp)
    class(F_mode_rank1_point),intent(in)       :: this
    type(lattice),intent(in)                   :: lat       !lattice type which knows about all states
    real(8),intent(out),pointer                :: mode(:)   !pointer to required mode
    real(8),allocatable,target,intent(inout)   :: tmp(:)    !not used here

    Call lat%set_order_point(this%order,mode)
end subroutine

subroutine get_mode_exc(this,lat,op_exc,vec)
    use, intrinsic :: iso_fortran_env, only : error_unit
    class(F_mode_rank1_point),intent(in)        :: this
    type(lattice),intent(in)                    :: lat      !lattice type which knows about all states
    integer,intent(in)                          :: op_exc   !of which operator the first entry is kept
    real(8),intent(inout)                       :: vec(:)

    ERROR STOP "Calling get_mode_ext does not make sense for a rank1 mode"
end subroutine

subroutine mode_reduce(this,lat,vec_in,op_keep,vec_out)
    use, intrinsic :: iso_fortran_env, only : error_unit
    class(F_mode_rank1_point),intent(in)        :: this
    real(8),intent(in)                          :: vec_in(:)
    type(lattice),intent(in)                    :: lat       !lattice type which knows about all states
    integer,intent(in)                          :: op_keep   !of which operator the first entry is kept
    real(8),intent(out)                         :: vec_out(lat%dim_modes(op_keep)*lat%Ncell)

    ERROR STOP "Calling mode_reduce does not make sense for a rank1 mode"
end subroutine

function is_same(this,comp)result(same)
    class(F_mode_rank1_point),intent(in)       :: this
    class(F_mode),intent(in)                   :: comp
    logical                                    :: same

    same=.false.
    select type(comp) 
    type is(F_mode_rank1_point)
        same=this%order==comp%order
    end select
end function

subroutine destroy(this)
    !nothing really has to be done here
    class(F_mode_rank1_point),intent(inout) ::  this
    this%order=0
end subroutine

subroutine copy(this,F_out)
    class(F_mode_rank1_point),intent(in)    :: this
    class(F_mode),allocatable,intent(inout) :: F_out

    Call this%copy_base(F_out)
    select type(F_out)
    class is(F_mode_rank1_point)
        F_out%order=this%order
    class default
        ERROR STOP "FAILED TO COPY F_mode_rank1_pointer mode to F_out"
    end select
end subroutine

subroutine bcast(this,comm)
    use mpi_basic                
    class(F_mode_rank1_point),intent(inout) ::  this        !this might fail if the server threads non-allocated class(F_mode), TAKE CARE OF THIS IN HAM_BASE
    type(mpi_type),intent(in)               ::  comm
#ifdef CPP_MPI
    integer     :: ierr
  
    !THIS MIGHT BE INSUFFICIENT, MAYBE ONE HAS TO CHECK IF THE F_MODE IS ALREADY ALLOCATED TO THE F_mode_rank1_point type
    STOP "CHECK IF THIS WORKS WITHOUT PREVIOUS ALLOCATION./type stuff/, on non-master threads"
    Call MPI_Bcast(this%order,1, MPI_INTEGER, comm%mas, comm%com,ierr)
    if(ierr/=0) ERROR STOP "MPI BCAST FAILED"
#else
    continue
#endif
end subroutine 

subroutine init_order(this,abbrev_in)
    use m_derived_types, only: op_abbrev_to_int
    class(F_mode_rank1_point),intent(inout) :: this
    character(len=1), intent(in)            :: abbrev_in
    integer                                 :: order(1)
    integer                                 :: order_occ(number_different_order_parameters)

    order=op_abbrev_to_int(abbrev_in)
    this%order=order(1)
    order_occ=0
    order_occ(order)=1
    Call this%init_base(order_occ)
end subroutine
end module
