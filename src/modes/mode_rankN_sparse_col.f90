module m_mode_construction_rankN_sparse_col
use m_mode_construction
use m_derived_types, only : lattice,number_different_order_parameters
use m_coo_mat
implicit none
private
public F_mode_rankN_sparse_col, col_mat

type col_mat
    integer :: dim_mat(2)=0
    integer :: nnz=0
    integer,allocatable :: col(:)
end type

type, extends(F_mode) :: F_mode_rankN_sparse_col 
    integer                     :: mode_size=-1
    type(col_mat),allocatable   :: dat(:)
    contains
    !necessary routines as defined by class
    procedure   :: get_mode   !subroutine which returns the mode 
    procedure   :: get_mode_exc_ind
    procedure   :: mode_reduce_ind
    procedure   :: get_mode_single_cont

    procedure   :: copy
    procedure   :: bcast
    procedure   :: destroy
    procedure   :: is_same
    !local construction routine
    procedure   :: init_order
end type

contains


subroutine get_mode_single_cont(this,lat,order,i,modes,vec,bnd)
    class(F_mode_rankN_sparse_col),intent(in)  :: this
    type(lattice),intent(in)                    :: lat
    integer,intent(in)                          :: order
    integer,intent(in)                          :: i
    real(8),pointer,intent(out)                 :: modes(:)
    integer,intent(out)                         :: bnd(2)
    real(8),allocatable,target,intent(out)      :: vec(:)   !space to allocate array if not single operator

    ERROR STOP "IMPLEMENT"
end subroutine


subroutine get_mode_exc_ind(this,lat,ind,vec)
    use, intrinsic :: iso_fortran_env, only : error_unit
    class(F_mode_rankN_sparse_col),intent(in)   :: this
    type(lattice),intent(in)                    :: lat       !lattice type which knows about all states
    integer,intent(in)                          :: ind
    real(8),intent(inout)                       :: vec(:)

    real(8)         :: tmp_internal(this%mode_size,this%N_mode)
    real(8),pointer :: mode_base(:)
    integer         :: i

    tmp_internal=1.d0
    do i=1,ind-1
        Call lat%set_order_point(this%order(i),mode_base)
        tmp_internal(:,i)=mode_base(this%dat(i)%col)
    enddo
    do i=ind+1,this%N_mode
        Call lat%set_order_point(this%order(i),mode_base)
        tmp_internal(:,i)=mode_base(this%dat(i)%col)
    enddo
    vec=product(tmp_internal,dim=2)
    nullify(mode_base)
end subroutine

subroutine mode_reduce_ind(this,lat,vec_in,ind,vec_out)
    use, intrinsic :: iso_fortran_env, only : error_unit
    class(F_mode_rankN_sparse_col),intent(in)  :: this
    real(8),intent(in)                          :: vec_in(:)
    type(lattice),intent(in)                    :: lat       !lattice type which knows about all states
    integer,intent(in)                          :: ind
    real(8),intent(out)                         :: vec_out(lat%dim_modes(this%order(ind))*lat%Ncell)

    integer     ::  i

    vec_out=0.0d0
    do i=1,this%dat(ind)%nnz
        vec_out(this%dat(ind)%col(i))=vec_out(this%dat(ind)%col(i))+vec_in(i)
    enddo
end subroutine


subroutine get_mode(this,lat,mode,tmp)
    class(F_mode_rankN_sparse_col),intent(in)   :: this
    type(lattice),intent(in)                    :: lat       !lattice type which knows about all states
    real(8),intent(out),pointer                 :: mode(:)   !pointer to required mode
    real(8),allocatable,target,intent(inout)    :: tmp(:)

    real(8)         :: tmp_internal(this%mode_size,size(this%dat))
    real(8),pointer :: mode_base(:)

    integer         :: i

    allocate(tmp(this%mode_size),source=0.0d0)
    mode=>tmp

    tmp_internal=0.d0
    do i=1,size(this%dat)
        Call lat%set_order_point(this%order(i),mode_base)
        tmp_internal(:,i)=mode_base(this%dat(i)%col)
    enddo
    mode=product(tmp_internal,dim=2)
    nullify(mode_base)
end subroutine

function is_same(this,comp)result(same)
    class(F_mode_rankN_sparse_col),intent(in)  :: this
    class(F_mode),intent(in)                   :: comp
    logical                                    :: same

    ERROR STOP "IMPLEMENT"
end function

subroutine destroy(this)
    class(F_mode_rankN_sparse_col),intent(inout) ::  this
    integer ::  i
    this%mode_size=-1
    this%order_occ=0
    do i=1,size(this%dat)
        deallocate(this%dat(i)%col)
    enddo
    deallocate(this%dat)
    deallocate(this%order)
end subroutine

subroutine copy(this,F_out)
    class(F_mode_rankN_sparse_col),intent(in)    :: this
    class(F_mode),allocatable,intent(inout)     :: F_out

    integer ::  i

    Call this%copy_base(F_out)
    select type(F_out)
    class is(F_mode_rankN_sparse_col)
        F_out%mode_size=this%mode_size
        allocate(F_out%dat(size(this%dat)))
        do i=1,size(this%dat)
            F_out%dat(i)%dim_mat=this%dat(i)%dim_mat
            F_out%dat(i)%nnz=this%dat(i)%nnz
            allocate(F_out%dat(i)%col,source=this%dat(i)%col)
        enddo
    class default
        ERROR STOP "FAILED TO COPY F_mode_rankN_sparse_col mode to F_out"
    end select
end subroutine

subroutine bcast(this,comm)
    use mpi_basic                
    class(F_mode_rankN_sparse_col),intent(inout) ::  this        !this might fail if the server threads non-allocated class(F_mode), TAKE CARE OF THIS IN HAM_BASE
    type(mpi_type),intent(in)               ::  comm
#ifdef CPP_MPI
    integer     :: ierr
    integer     ::  N
  
    !THIS MIGHT BE INSUFFICIENT, MAYBE ONE HAS TO CHECK IF THE F_MODE IS ALREADY ALLOCATED TO THE F_mode_rankN_sparse_col type
    STOP "CHECK IF THIS WORKS WITHOUT PREVIOUS ALLOCATION./type stuff/, on non-master threads"
    Call bcast_base(this,comm)
    Call MPI_Bcast(this%mode_size,1, MPI_INTEGER, comm%mas, comm%com,ierr)

    ERROR STOP "ALSO TOTALLY UNTESTED"
    !bcast mat
    do i=1,N
        Call MPI_Bcast(this%dat(i)%nnz    ,1, MPI_INTEGER, comm%mas, comm%com,ierr)
        Call MPI_Bcast(this%dat(i)%dim_mat,2, MPI_INTEGER, comm%mas, comm%com,ierr)
        if(.not.comm%ismas)then
            allocate(this%dat(i)%col(this%mat(i)%nnz))
        endif
        Call MPI_Bcast(this%dat(i)%col,this%dat(i)%nnz, MPI_INTEGER         , comm%mas, comm%com,ierr)
    enddo
#else
    continue
#endif
end subroutine 

subroutine init_order(this,lat,abbrev_in,mat)
    use m_derived_types, only: op_abbrev_to_int
    class(F_mode_rankN_sparse_col),intent(inout) :: this
    type(lattice),intent(in)                :: lat       !lattice type which knows about all states
    character(len=*), intent(in)            :: abbrev_in !considered order abbreviations
    type(coo_mat),intent(inout)             :: mat(:)    !input matrices, destroyed when returned
    integer     :: order(len(abbrev_in))
    integer     :: i     

    order=op_abbrev_to_int(abbrev_in)
    Call this%init_base(order)
    if(size(mat)/=len(abbrev_in)) ERROR STOP "Matrix size has the be the same as the length of abbrev_in"
    allocate(this%dat(size(mat)))
    do i=1,size(mat)
        this%dat(i)%nnz     =mat(i)%nnz
        this%dat(i)%dim_mat =mat(i)%dim_mat
        Call move_alloc(mat(i)%col,this%dat(i)%col)
        Call mat(i)%destroy()
    enddo
    this%mode_size=this%dat(1)%dim_mat(1)
end subroutine
end module
