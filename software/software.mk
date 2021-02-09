include $(SEM_DIR)/core.mk

SEM_SW_DIR:=$(SEM_DIR)/software

#include
INCLUDE+=-I$(SEM_SW_DIR)

#headers
HDR+=$(SEM_SW_DIR)/*.h
