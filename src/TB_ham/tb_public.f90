module m_H_tb_public
use m_H_tb_base
use m_H_tb_coo
use m_H_tb_dense
use m_H_tb_csr
use m_TB_types, only: parameters_TB_IO_H
private set_H_single, set_H_multiple
interface set_H
    module procedure set_H_single
    module procedure set_H_multiple
end interface

contains

subroutine H_append(H,Hadd)
    !adds the entries from Hadd to H, and destroys the Hadd array
    type(H_tb_coo),allocatable,intent(inout)   :: H(:)
    type(H_tb_coo),allocatable,intent(inout)   :: Hadd(:)

    type(H_tb_coo),allocatable                 :: Htmp(:)
    !unfortunately does not work with classes...
    !class(H_tb),allocatable,intent(inout)   :: H(:)
    !class(H_tb),allocatable,intent(inout)   :: Hadd(:)

    !class(H_tb),allocatable                 :: Htmp(:)

    integer ::  i

    allocate(Htmp(size(H)+size(Hadd)),mold=H)
    do i=1,size(H)
        Call H(i)%mv(Htmp(i))
    enddo
    do i=1,size(Hadd)
        Call Hadd(i)%mv(Htmp(i+size(H)))
    enddo
    deallocate(H,Hadd)
    Call move_alloc(Htmp,H)
end subroutine

subroutine set_H_single(H,io)
    use, intrinsic :: iso_fortran_env, only : output_unit, error_unit
    class(H_tb),allocatable,intent(inout)   :: H
    type(parameters_TB_IO_H),intent(in)     :: io

    if(allocated(H)) STOP "CANNOT set H which is already set"
    if(io%sparse)then
        write(output_unit,'(2/A/)') "Chose sparse feast algoritm for tight-binding Hamiltonian"
        allocate(H_feast_csr::H)
    else
        select case(io%i_diag)
        case(1)
            write(output_unit,'(2/A/)') "Chose lapack zheevd algoritm for tight-binding Hamiltonian"
            allocate(H_zheevd::H)
        case(2)
            write(output_unit,'(2/A/)') "Chose lapack zheev algoritm for tight-binding Hamiltonian"
            allocate(H_zheev::H)
        case(3)
            write(output_unit,'(2/A/)') "Chose dense feast algoritm for tight-binding Hamiltonian"
            allocate(H_feast_den::H)
        case(4)
            write(output_unit,'(2/A/)') "Chose lapack zheevr algoritm for tight-binding Hamiltonian"
            allocate(H_zheevr::H)
        case default
            write(error_unit,'(2/A,I6,A)') "Unable to choose dense tight-binding Hamiltonian as TB_diag=",io%i_diag," is not implemented"
            STOP "CHECK INPUT"
        end select
    endif
end subroutine

subroutine set_H_multiple(H,N,io)
    use, intrinsic :: iso_fortran_env, only : output_unit, error_unit
    class(H_tb),allocatable,intent(inout)   :: H(:)
    integer,intent(in)                      :: N
    type(parameters_TB_IO_H),intent(in)     :: io

    if(allocated(H)) STOP "CANNOT set H which is already set"
    if(io%sparse)then
        write(output_unit,'(2/A/)') "Chose sparse feast algoritm for tight-binding Hamiltonian"
        allocate(H_feast_csr::H(N))
    else
        select case(io%i_diag)
        case(1)
            write(output_unit,'(2/A/)') "Chose lapack zheevd algoritm for tight-binding Hamiltonian"
            allocate(H_zheevd::H(N))
        case(2)
            write(output_unit,'(2/A/)') "Chose lapack zheev algoritm for tight-binding Hamiltonian"
            allocate(H_zheev::H(N))
        case(3)
            write(output_unit,'(2/A/)') "Chose dense feast algoritm for tight-binding Hamiltonian"
            allocate(H_feast_den::H(N))
        case(4)
            write(output_unit,'(2/A/)') "Chose lapack zheevr algoritm for tight-binding Hamiltonian"
            allocate(H_zheevr::H(N))
        case default
            write(error_unit,'(2/A,I6,A)') "Unable to choose dense tight-binding Hamiltonian as TB_diag=",io%i_diag," is not implemented"
            STOP "CHECK INPUT"
        end select
    endif
end subroutine


end module
