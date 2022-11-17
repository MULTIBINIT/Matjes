#check the different include directories
message("Search for include directory")
if (DEFINED ENV{LD_LIBRARY_PATH})
      message("LD_LIBRARY_PATH environment variable found and compiling with it.")
      set(LD_LIB $ENV{LD_LIBRARY_PATH})
      string(REPLACE ":" " -I" LD_LIBRARY_PATH ${LD_LIB})
   elseif(DEFINED $LD_LIBRARY_PATH)
      message("LD_LIBRARY_PATH environment variable set by use to: ${LD_LIBRARY_PATH} ")
   else()
      message("default LD_LIBRARY_PATH selected: /usr/local/include")
      set(LD_LIBRARY_PATH "/usr/local/include")
endif()
 
#cmake file to set compiler flags for some of the known compilers
if (${CMAKE_Fortran_COMPILER_ID} MATCHES "Intel")
    message("Intel Fortran detected")
    message("THESE FLAGS ARE NOT TESTED")
    
    if(DEFINED USE_OPENMP)
        if (${CMAKE_Fortran_COMPILER_VERSION} VERSION_LESS "14.1.0.0")
        	set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -openmp")
        else()
        	set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -qopenmp")
        endif()     
    endif()
    
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fpp")
    set(CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS_RELEASE} -O3")
    if(${COMPOP} STREQUAL "debug")
    	set(CMAKE_Fortran_FLAGS_DEBUG "${CMAKE_Fortran_FLAGS_DEBUG} -O0 -ftrapuv -fp-stack-check -auto -fpe0 -check bounds -heap-arrays -g -traceback -warn -gen-interfaces -init=snan,arrays")
    elseif(${COMPOP} STREQUAL "check")
    	set(CMAKE_Fortran_FLAGS_DEBUG "${CMAKE_Fortran_FLAGS_DEBUG} -O0 -fpe0 -heap-arrays -C -traceback -warn -gen-interfaces -init=snan,arrays -g ")
    else()
    	message("unexpected COMPOP : ${COMPOP}")
    endif()
elseif(${CMAKE_Fortran_COMPILER_ID} MATCHES "GNU")
    message("gfortran detected")
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -ffree-form -fimplicit-none -ffree-line-length-none -x f95-cpp-input")
    set(CMAKE_Fortran_FLAGS_RELEASE "-O3 ${CMAKE_Fortran_FLAGS_RELEASE}")

    if(USE_OPENMP)
        set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fopenmp")
    endif()

    if(${COMPOP} STREQUAL "check")
    	set(CMAKE_Fortran_FLAGS_DEBUG "-O0 -g -fcheck=all -Wall -fbacktrace -ffree-form -finit-real=snan  -ffpe-trap=invalid,overflow,zero,underflow,denormal ${CMAKE_Fortran_FLAGS_DEBUG}")
    elseif(${COMPOP} STREQUAL "debug")
    	SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pg")
            SET(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -pg")
    	set(CMAKE_Fortran_FLAGS_DEBUG "-Og -g  -pg -lprofiler -fcheck=all -Wall -fbacktrace -ffpe-trap=invalid,overflow,zero,underflow,denormal ${CMAKE_Fortran_FLAGS_DEBUG}")
    elseif(${COMPOP} STREQUAL "release")
    else()
    	message("unexpected COMPOP : ${COMPOP}")
    endif()
elseif(${CMAKE_Fortran_COMPILER_ID} MATCHES "Cray")
   message("cray detected")
   set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -e Z")
else()
  message(WARNING "\n\n\n Fortran compiler detected without default flags, make sure reasonable flags are added manually\n\n\n")
endif()
set(CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS_RELEASE} ${compadd} ${com_rel_add}")
set(CMAKE_Fortran_FLAGS_DEBUG "${CMAKE_Fortran_FLAGS_DEBUG} ${compadd} ${com_deb_add}")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} ${compadd} ${com_rel_add}")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} ${compadd} ${com_deb_add}")


if(${CMAKE_CXX_COMPILER_ID} MATCHES "GNU")
   message("g++ detected")
   set(CMAKE_CXX_FLAGS "-fopenmp ${CMAKE_CXX_FLAGS}")   #add here general lines
   set(CMAKE_CXX_FLAGS_RELEASE "-O3 ${CMAKE_CXX_FLAGS_RELEASE}")
   set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -I${LD_LIBRARY_PATH}")

    if(USE_OPENMP)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fopenmp")
    endif()

	if(${COMPOP} STREQUAL "check")
		set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g -Wall ${CMAKE_CXX_FLAGS_DEBUG}")
	elseif(${COMPOP} STREQUAL "debug")
		set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g3 -pg -Wall ${CMAKE_CXX_FLAGS_DEBUG}")
    endif()
else()
  message(WARNING "C++ compiler detected without default flags, make sure reasonable flags are added manually or implement something reasonable in cmake/compilerflags")
endif()

if(${CMAKE_C_COMPILER_ID} MATCHES "GNU")
   message("gcc detected")
   set(CMAKE_C_FLAGS_RELEASE "-O3 ${CMAKE_C_FLAGS_RELEASE}")
   set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -I${LD_LIBRARY_PATH}")

    if(${COMPOP} STREQUAL "check")
        set(CMAKE_C_FLAGS_DEBUG "-O0 -g -Wall ${CMAKE_C_FLAGS_DEBUG}")
    elseif(${COMPOP} STREQUAL "debug")
        set(CMAKE_C_FLAGS_DEBUG "-O0 -g3 -pg -Wall ${CMAKE_C_FLAGS_DEBUG}")
    endif()
else()
  message(WARNING "C compiler detected without default flags, make sure reasonable flags are added manually or implement something reasonable in cmake/compilerflags")
endif()

if(CMAKE_CUDA_COMPILER)
    set(CMAKE_CUDA_FLAGS_DEBUG "-g -G -Xcompiler -rdynamic")
    set(CMAKE_CUDA_FLAGS_RELEASE "-Xptxas -O3,-v --generate-line-info")
else()
    message("\nNo cuda compiler set.\n")
endif()
