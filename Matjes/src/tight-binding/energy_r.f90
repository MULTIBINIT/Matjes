module m_energy_r
    use m_tb_types 
    use m_derived_types, only: lattice
    use m_energy_solve_dense
    use m_energy_set_real_sc, only: set_Hr_dense_sc
    use m_energy_set_real, only: set_Hr_dense_nc
#ifdef CPP_MKL_SPBLAS
    use MKL_SPBLAS
    use m_energy_solve_sparse
    use m_energy_set_real_sparse_sc, only: set_Hr_sparse_sc
    use m_energy_set_real_sparse, only: set_Hr_sparse_nc
#endif

    implicit none

    private
    public :: get_eigenval_r,get_eigenvec_r,init_Hr!,set_Hr_dense,set_Hr
    !large electronic Hamiltonian
    complex(8),allocatable  ::  Hr(:,:)
#ifdef CPP_MKL_SPBLAS
    type(SPARSE_MATRIX_T)   ::  Hr_sparse
    public :: set_hr_sparse
#endif

    contains

    subroutine init_Hr(lat,h_par,h_io,mode_mag)
        type(lattice),intent(in)                :: lat
        type(parameters_TB_Hsolve),intent(in)   :: h_par
        type(parameters_TB_IO_H),intent(in)     :: h_io
        real(8),intent(in)                      :: mode_mag(:,:)

        if(h_par%sparse)then
#ifdef CPP_MKL_SPBLAS
            Call set_Hr_sparse(lat,h_par,h_io,mode_mag,Hr_sparse)
#else
            STOP "requires CPP_MKL_SPBLAS for sparse TB"
#endif
        else
            Call set_Hr_dense(lat,h_par,h_io,mode_mag,Hr)
        endif
    end subroutine 

#ifdef CPP_MKL_SPBLAS
    subroutine set_Hr_sparse(lat,h_par,h_io,mode_mag,Hr_set)
        type(lattice),intent(in)                :: lat
        type(parameters_TB_Hsolve),intent(in)    ::  h_par
        type(parameters_TB_IO_H),intent(in)     :: h_io
        type(SPARSE_MATRIX_T),intent(out)        ::  Hr_set
        real(8),intent(in)                       ::  mode_mag(:,:)

        if(h_par%nsc==2)then
            Call set_Hr_sparse_sc(lat,h_par,h_io,mode_mag,Hr_set)
        else
            Call set_Hr_sparse_nc(lat,h_par,h_io,mode_mag,Hr_set)
        endif
    end subroutine 
#endif

    subroutine set_Hr_dense(lat,h_par,h_io,mode_mag,Hr_set)
        type(lattice),intent(in)                :: lat
        type(parameters_TB_Hsolve),intent(in)    ::  h_par
        type(parameters_TB_IO_H),intent(in)      :: h_io
        complex(8),allocatable,intent(inout)     ::  Hr_set(:,:)
        real(8),intent(in)                       ::  mode_mag(:,:)

        if(h_par%nsc==2)then
            Call set_Hr_dense_sc(lat,h_par,h_io,mode_mag,Hr_set)
        else
            Call set_Hr_dense_nc(lat,h_par,h_io,mode_mag,Hr_set)
        endif
    end subroutine 

    !subroutine get_Hr(dimH,Hr_out)
    !    !not sure if needed anymore
    !    integer,intent(in)          ::  dimH
    !    complex(8),intent(out)      ::  Hr_out(dimH,dimH)
    !    
    !    if(.not.allocated(Hr)) STOP "Hr is not allocated but get_Hr is called"
    !    if(dimH/=size(Hr,1)) STOP "dimensions of Hr seems to be wrong for getting Hr"
    !    Hr_out=Hr
    !end subroutine 

    subroutine get_eigenval_r(h_par,eigval)
        type(parameters_TB_Hsolve),intent(in)     ::  h_par
        real(8),intent(out),allocatable           ::  eigval(:)
    
        if(h_par%sparse)then
#ifdef CPP_MKL_SPBLAS
            Call HR_eigval_sparse_feast(h_par,Hr_sparse,eigval)
#else
            STOP 'Cannot use spase get_eigenvalue without CPP_MKL_SPBLAS'
#endif
        else
            if(h_par%i_diag==1)then
                Call Hr_eigval_feast(h_par,Hr,eigval)
            elseif(h_par%i_diag==2)then
                Call Hr_eigval_zheev(h_par,Hr,eigval)
            elseif(h_par%i_diag==3)then
                Call Hr_eigval_zheevd(h_par,Hr,eigval)
            elseif(h_par%i_diag==4)then
                Call Hr_eigval_zheevr(h_par,Hr,eigval)
            else
                write(*,*) "trying to use h_par%i_diag=",h_par%i_diag
                STOP "h_par%diag choice not implemented for get_eigenval_r"
            endif
        endif
    end subroutine


    subroutine get_eigenvec_r(h_par,eigval,eigvec)
        type(parameters_TB_Hsolve),intent(in)     :: h_par
        real(8),intent(out),allocatable           :: eigval(:)
        complex(8),intent(out),allocatable        :: eigvec(:,:)

        if(h_par%sparse)then
#ifdef CPP_MKL_SPBLAS
            Call HR_eigvec_sparse_feast(h_par,Hr_sparse,eigvec,eigval)
#else
            STOP 'Cannot use spase get_eigenvalue without CPP_MKL_SPBLAS'
#endif
        else
            if(h_par%i_diag==1)then
                Call Hr_eigvec_feast(h_par,Hr,eigvec,eigval)
            elseif(h_par%i_diag==2)then
                Call Hr_eigvec_zheev(h_par,Hr,eigvec,eigval)
            elseif(h_par%i_diag==3)then
                Call Hr_eigvec_zheevd(h_par,Hr,eigvec,eigval)
            elseif(h_par%i_diag==4)then
                Call Hr_eigvec_zheevr(h_par,Hr,eigvec,eigval)
            else
                write(*,*) "trying to use h_par%i_diag=",h_par%i_diag
                STOP "h_par%diag choice not implemented for get_eigenval_r"
            endif
        endif

    end subroutine


end module m_energy_r
