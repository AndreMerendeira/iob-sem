SEM_HW_DIR:=$(SEM_DIR)/hardware

#include
SEM_INC_DIR:=$(SEM_HW_DIR)/include
INCLUDE+=$(incdir) $(SEM_INC_DIR)

#headers
VHDR+=$(wildcard $(SEM_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(SEM_HW_DIR)/src/*.v)
